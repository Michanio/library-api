require "rails_helper"

RSpec.describe Catalog::ListBooks do
  it "returns active books ordered by serial number" do
    create(:book, serial_number: "000200")
    create(:book, serial_number: "000100")
    create(:book, :deleted, serial_number: "000150")

    expect(described_class.call.map(&:serial_number)).to eq(%w[000100 000200])
  end

  it "returns an empty list when there are no books" do
    expect(described_class.call).to eq([])
  end
end
