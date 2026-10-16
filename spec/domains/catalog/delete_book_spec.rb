require "rails_helper"

RSpec.describe Catalog::DeleteBook do
  it "soft-deletes the book" do
    book = create(:book, serial_number: "000123")

    expect { described_class.call("000123") }.not_to change(Catalog::Book, :count)
    expect(book.reload.deleted_at).to be_present
  end

  it "raises BookNotFound for an unknown serial number" do
    expect { described_class.call("999999") }.to raise_error(Catalog::BookNotFound)
  end

  it "raises BookNotFound for a book that's already deleted" do
    create(:book, :deleted, serial_number: "000123")

    expect { described_class.call("000123") }.to raise_error(Catalog::BookNotFound)
  end
end
