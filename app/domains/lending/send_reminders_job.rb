module Lending
  # Runs daily, scheduled in config/recurring.yml (ADR 0009).
  class SendRemindersJob < ApplicationJob
    def perform
      SendReminders.call
    end
  end
end
