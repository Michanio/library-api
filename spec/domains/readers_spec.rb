require "rails_helper"

# The public interface other domains and controllers rely on. Edge cases are
# covered by the service object specs in spec/domains/readers/.
RSpec.describe Readers do
  it "finds a reader by library card number and lists readers by ID" do
    reader = create(:reader, library_card_number: "004217")

    found = described_class.find_reader("004217")
    expect(found).to be_a(Readers::ReaderData)
    expect(described_class.list_readers(ids: [ reader.id ])).to eq([ found ])
  end

  it "raises its own errors, not Active Record ones" do
    expect { described_class.find_reader("999999") }.to raise_error(Readers::ReaderNotFound)
  end
end
