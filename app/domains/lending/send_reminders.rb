module Lending
  # Queues the return reminders that are due (ADR 0009): one when a loan is due within
  # DUE_SOON_DAYS days, and one when it's due. Each reminder is recorded on the
  # borrowing when it's queued, so running this twice sends nothing new, and a
  # reminder missed because the job didn't run is sent on the next run.
  class SendReminders
    DUE_SOON_DAYS = 3

    def self.call(...) = new(...).call

    def initialize(today: Date.current)
      @today = today
    end

    def call
      reminders = due_soon.map { |borrowing| [ :due_soon, borrowing ] } +
        due_today.map { |borrowing| [ :due_today, borrowing ] }
      return 0 if reminders.empty?

      borrowings = reminders.map(&:last)
      books_by_id = Catalog.list_books(ids: borrowings.map(&:book_id).uniq).index_by(&:id)
      readers_by_id = Readers.list_readers(ids: borrowings.map(&:reader_id).uniq).index_by(&:id)

      reminders.count do |kind, borrowing|
        send_reminder(kind, borrowing, books_by_id.fetch(borrowing.book_id), readers_by_id.fetch(borrowing.reader_id))
      end
    end

    private
      # Due within DUE_SOON_DAYS days, but not yet: a loan that's already due only
      # gets the due-today reminder.
      def due_soon
        Borrowing.current.where(due_soon_reminder_sent_at: nil, due_on: (@today + 1)..(@today + DUE_SOON_DAYS))
      end

      # Due today, or earlier if the reminder was missed.
      def due_today
        Borrowing.current.where(due_today_reminder_sent_at: nil, due_on: ..@today)
      end

      # Claims the reminder with a conditional update, so concurrent runs can't both
      # send it, then queues the email. If queuing fails, the claim is rolled back.
      def send_reminder(kind, borrowing, book, reader)
        sent_at_column = :"#{kind}_reminder_sent_at"
        Borrowing.transaction do
          claimed = Borrowing.where(id: borrowing.id, sent_at_column => nil).update_all(sent_at_column => Time.current)
          next false if claimed.zero?

          ReminderMailer.with(
            email: reader.email, full_name: reader.full_name,
            title: book.title, serial_number: book.serial_number, due_on: borrowing.due_on
          ).public_send(kind).deliver_later
          true
        end
      end
  end
end
