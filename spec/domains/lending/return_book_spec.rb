require "rails_helper"

RSpec.describe Lending::ReturnBook do
  it "closes the current borrowing" do
    borrowing = create(:borrowing, borrowed_at: 2.days.ago)

    freeze_time do
      returned = described_class.call(book_id: borrowing.book_id)

      expect(returned).to have_attributes(id: borrowing.id, returned_at: Time.current)
      expect(returned).to be_returned
      expect(Lending::Borrowing.current).to be_empty
    end
  end

  it "raises BookNotBorrowed if the book isn't out" do
    borrowing = create(:borrowing, :returned)

    expect { described_class.call(book_id: borrowing.book_id) }.to raise_error(Lending::BookNotBorrowed)
  end

  it "raises BookNotBorrowed for a book that was never borrowed" do
    expect { described_class.call(book_id: create(:book).id) }.to raise_error(Lending::BookNotBorrowed)
  end
end
