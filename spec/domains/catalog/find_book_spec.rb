require "rails_helper"

RSpec.describe Catalog::FindBook do
  it "returns the book with its authors" do
    author = create(:author, name: "Frank Herbert")
    book = create(:book, serial_number: "000123", authors: [ author ])

    expect(described_class.call("000123")).to have_attributes(
      id: book.id, serial_number: "000123", authors: [ Catalog::AuthorData.new(id: author.id, name: "Frank Herbert") ]
    )
  end

  it "raises BookNotFound for an unknown serial number" do
    expect { described_class.call("999999") }.to raise_error(Catalog::BookNotFound)
  end

  it "raises BookNotFound for a deleted book" do
    create(:book, :deleted, serial_number: "000123")

    expect { described_class.call("000123") }.to raise_error(Catalog::BookNotFound)
  end
end
