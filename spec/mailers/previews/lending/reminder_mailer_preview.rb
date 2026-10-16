# Previews at http://localhost:3000/rails/mailers/lending/reminder_mailer
module Lending
  class ReminderMailerPreview < ActionMailer::Preview
    def due_soon
      ReminderMailer.with(**loan(due_on: Date.current + SendReminders::DUE_SOON_DAYS)).due_soon
    end

    def due_today
      ReminderMailer.with(**loan(due_on: Date.current)).due_today
    end

    def due_today_overdue
      ReminderMailer.with(**loan(due_on: Date.current - 2)).due_today
    end

    private
      def loan(due_on:)
        { email: "jane.doe@example.com", full_name: "Jane Doe", title: "Dune", serial_number: "000123", due_on: }
      end
  end
end
