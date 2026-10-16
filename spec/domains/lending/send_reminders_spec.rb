require "rails_helper"

RSpec.describe Lending::SendReminders do
  let(:today) { Date.new(2026, 3, 28) }
  let(:reader) { create(:reader, email: "jane@example.com", full_name: "Jane Doe") }
  let(:book) { create(:book, serial_number: "000123", title: "Dune") }

  around { |example| travel_to(today) { example.run } }

  def borrowing(due_on:, **attributes)
    create(:borrowing, book_id: book.id, reader_id: reader.id, borrowed_at: (due_on - 30).in_time_zone, due_on:, **attributes)
  end

  def send_reminders = described_class.call(today:)

  def reminder(kind, due_on:)
    have_enqueued_mail(Lending::ReminderMailer, kind).with(
      params: { email: "jane@example.com", full_name: "Jane Doe", title: "Dune", serial_number: "000123", due_on: },
      args: []
    )
  end

  it "sends the due-soon reminder 3 days before the due date" do
    loan = borrowing(due_on: today + 3)

    expect { expect(send_reminders).to eq(1) }.to reminder(:due_soon, due_on: today + 3)
    expect(loan.reload.due_soon_reminder_sent_at).to eq(Time.current)
  end

  it "doesn't send anything more than 3 days before the due date" do
    borrowing(due_on: today + 4)

    expect { expect(send_reminders).to eq(0) }.not_to have_enqueued_mail
  end

  it "sends the due-today reminder on the due date" do
    loan = borrowing(due_on: today, due_soon_reminder_sent_at: 3.days.ago)

    expect { expect(send_reminders).to eq(1) }.to reminder(:due_today, due_on: today)
    expect(loan.reload.due_today_reminder_sent_at).to eq(Time.current)
  end

  it "sends nothing new when it runs again" do
    borrowing(due_on: today + 3)
    borrowing(due_on: today, book_id: create(:book).id)
    send_reminders

    expect { expect(send_reminders).to eq(0) }.not_to have_enqueued_mail
  end

  it "catches up on a due-soon reminder missed by up to 2 days" do
    borrowing(due_on: today + 1)

    expect { send_reminders }.to reminder(:due_soon, due_on: today + 1)
  end

  it "only sends the due-today reminder for a loan that's already due" do
    borrowing(due_on: today - 2)

    expect { expect(send_reminders).to eq(1) }.to reminder(:due_today, due_on: today - 2)
  end

  it "doesn't remind about returned books" do
    borrowing(due_on: today, returned_at: Time.current)

    expect(send_reminders).to eq(0)
  end

  it "doesn't send a reminder another run claimed in the meantime" do
    loan = borrowing(due_on: today + 3)
    allow(Lending::Borrowing).to receive(:transaction).and_wrap_original do |original, &block|
      loan.update_column(:due_soon_reminder_sent_at, 1.minute.ago) # the other run wins
      original.call(&block)
    end

    expect { expect(send_reminders).to eq(0) }.not_to have_enqueued_mail
  end

  it "uses the library's date by default" do
    borrowing(due_on: Date.current)

    expect(described_class.call).to eq(1)
  end
end
