require "rails_helper"

RSpec.describe LogDelivery do
  it "writes the email to the Rails log instead of sending it" do
    mail = Mail.new(from: "library@example.com", to: "jane@example.com", subject: "Reminder", body: "Please return it.")
    allow(Rails.logger).to receive(:info)

    described_class.new({}).deliver!(mail)

    expect(Rails.logger).to have_received(:info).with(
      a_string_including("To: jane@example.com", "Subject: Reminder", "Please return it.")
    )
  end
end
