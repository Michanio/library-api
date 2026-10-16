require "rails_helper"

RSpec.describe Lending::BorrowBook do
  let(:book) { create(:book) }
  let(:reader) { create(:reader) }

  it "lends the book for 30 days starting now" do
    travel_to Time.zone.local(2026, 3, 1, 10) do
      borrowing = described_class.call(book_id: book.id, reader_id: reader.id)

      expect(borrowing).to have_attributes(
        book_id: book.id, reader_id: reader.id, borrowed_at: Time.current, due_on: Date.new(2026, 3, 31), returned_at: nil
      )
      expect(Lending::Borrowing.current.find_by(book_id: book.id)).to be_present
    end
  end

  it "raises BookAlreadyBorrowed if the book is out" do
    create(:borrowing, book_id: book.id)

    expect { described_class.call(book_id: book.id, reader_id: reader.id) }.to raise_error(Lending::BookAlreadyBorrowed)
  end

  it "lends a book again after it was returned" do
    create(:borrowing, :returned, book_id: book.id)

    expect { described_class.call(book_id: book.id, reader_id: reader.id) }.to change(Lending::Borrowing, :count).by(1)
  end

  it "raises BookAlreadyBorrowed if another request lent the book after the check" do
    allow(Lending::Borrowing).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

    expect { described_class.call(book_id: book.id, reader_id: reader.id) }.to raise_error(Lending::BookAlreadyBorrowed)
  end
end
