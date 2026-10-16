require "rails_helper"

RSpec.describe Readers::FindReader do
  it "returns the reader with the library card number" do
    reader = create(:reader, library_card_number: "004217", full_name: "Jane Doe", email: "jane@example.com")

    expect(described_class.call("004217")).to eq(
      Readers::ReaderData.new(id: reader.id, library_card_number: "004217", full_name: "Jane Doe", email: "jane@example.com")
    )
  end

  it "raises ReaderNotFound for an unknown library card number" do
    expect { described_class.call("999999") }.to raise_error(Readers::ReaderNotFound)
  end
end
