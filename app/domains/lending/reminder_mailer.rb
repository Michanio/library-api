module Lending
  # Return reminders for readers (ADR 0009). Takes plain values rather than records,
  # so the emails can be queued without loading anything again.
  class ReminderMailer < ApplicationMailer
    before_action :assign_loan

    def due_soon
      mail to: params[:email], subject: "Reminder: please return \"#{@title}\" by #{@due_on_text}"
    end

    def due_today
      subject = @overdue ? "\"#{@title}\" was due on #{@due_on_text}" : "\"#{@title}\" is due today"
      mail to: params[:email], subject: "Reminder: #{subject}"
    end

    private
      def assign_loan
        @full_name = params[:full_name]
        @title = params[:title]
        @serial_number = params[:serial_number]
        @due_on = params[:due_on]
        @due_on_text = @due_on.strftime("%-d %B %Y")
        @days_left = (@due_on - Date.current).to_i
        @overdue = @days_left.negative?
      end
  end
end
