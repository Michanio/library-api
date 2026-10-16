require "rails_helper"

RSpec.describe Lending::ReminderMailer, type: :mailer do
  let(:loan) { { email: "jane@example.com", full_name: "Jane Doe", title: "Dune", serial_number: "000123" } }

  around { |example| travel_to(Date.new(2026, 3, 28)) { example.run } }

  describe "#due_soon" do
    it "reminds the reader of the due date" do
      mail = described_class.with(**loan, due_on: Date.new(2026, 3, 31)).due_soon

      expect(mail.to).to eq([ "jane@example.com" ])
      expect(mail.from).to eq([ "library@example.com" ])
      expect(mail.subject).to eq('Reminder: please return "Dune" by 31 March 2026')
      expect(mail.body.encoded).to include("Dear Jane Doe", "(serial number 000123)", "on 31 March 2026, in 3 days")
    end
  end

  describe "#due_today" do
    it "says the book is due today" do
      mail = described_class.with(**loan, due_on: Date.new(2026, 3, 28)).due_today

      expect(mail.subject).to eq('Reminder: "Dune" is due today')
      expect(mail.body.encoded).to include("is due back at the library today, 28 March 2026")
    end

    it "says when the book was due if the reminder is sent late" do
      mail = described_class.with(**loan, due_on: Date.new(2026, 3, 26)).due_today

      expect(mail.subject).to eq('Reminder: "Dune" was due on 26 March 2026')
      expect(mail.body.encoded).to include("was due back at the library on 26 March 2026")
    end
  end
end
