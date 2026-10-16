require "rails_helper"

RSpec.describe Lending::SendRemindersJob do
  it "sends the reminders that are due" do
    allow(Lending::SendReminders).to receive(:call)

    described_class.perform_now

    expect(Lending::SendReminders).to have_received(:call)
  end

  it "is scheduled daily in development and production" do
    recurring = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))

    %w[development production].each do |env|
      expect(recurring.dig(env, "send_return_reminders")).to include(
        "class" => "Lending::SendRemindersJob", "schedule" => "every day at 8am Europe/Warsaw"
      )
    end
  end
end
