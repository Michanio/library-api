require "rails_helper"

# The public interface other domains and controllers rely on. Edge cases are
# covered by the service object specs in spec/domains/catalog/.
RSpec.describe Catalog do
  let!(:author) { create(:author, name: "Frank Herbert") }

  it "adds, lists, finds and deletes books" do
    added = described_class.add_book(serial_number: "000123", title: "Dune", author_ids: [ author.id ])
    expect(added).to be_a(Catalog::BookData)

    expect(described_class.list_books).to eq([ added ])
    expect(described_class.find_book("000123")).to eq(added)

    expect(described_class.delete_book("000123")).to be_nil
    expect(described_class.list_books).to be_empty
  end

  it "raises its own errors, not Active Record ones" do
    expect { described_class.find_book("999999") }.to raise_error(Catalog::BookNotFound)
    expect {
      described_class.add_book(serial_number: "000123", title: "Dune", author_ids: [ 0 ])
    }.to raise_error(Catalog::BookInvalid)
  end
end
