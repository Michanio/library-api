require "rails_helper"

RSpec.describe Lending::BorrowingHistory do
  it "returns all borrowings of the book, newest first" do
    book = create(:book)
    oldest = create(:borrowing, :returned, book_id: book.id, borrowed_at: 3.months.ago)
    older = create(:borrowing, :returned, book_id: book.id, borrowed_at: 2.months.ago)
    current = create(:borrowing, book_id: book.id, borrowed_at: 1.day.ago)
    create(:borrowing) # another book

    expect(described_class.call(book_id: book.id).map(&:id)).to eq([ current.id, older.id, oldest.id ])
  end

  it "returns an empty list for a book that was never borrowed" do
    expect(described_class.call(book_id: create(:book).id)).to eq([])
  end
end
