require "rails_helper"

# The public interface other domains and controllers rely on. Edge cases are
# covered by the service object specs in spec/domains/lending/.
RSpec.describe Lending do
  let(:book) { create(:book) }
  let(:reader) { create(:reader) }

  it "borrows and returns a book, tracking its current borrowing and history" do
    borrowed = described_class.borrow_book(book_id: book.id, reader_id: reader.id)
    expect(borrowed).to be_a(Lending::BorrowingData)
    expect(described_class.current_borrowings(book_ids: [ book.id ])).to eq(book.id => borrowed)

    returned = described_class.return_book(book_id: book.id)
    expect(described_class.current_borrowings(book_ids: [ book.id ])).to eq({})
    expect(described_class.borrowing_history(book_id: book.id)).to eq([ returned ])
  end

  it "raises its own errors, not Active Record ones" do
    expect { described_class.return_book(book_id: book.id) }.to raise_error(Lending::BookNotBorrowed)

    described_class.borrow_book(book_id: book.id, reader_id: reader.id)
    expect {
      described_class.borrow_book(book_id: book.id, reader_id: reader.id)
    }.to raise_error(Lending::BookAlreadyBorrowed)
  end
end
