module Lending
  # The current borrowings of the given books, in one query, as
  # { book_id => BorrowingData }. Books that aren't out are left out.
  class CurrentBorrowings
    def self.call(...) = new(...).call

    def initialize(book_ids:)
      @book_ids = book_ids
    end

    def call
      Borrowing.current.where(book_id: @book_ids).to_h { |borrowing| [ borrowing.book_id, BorrowingData.from(borrowing) ] }
    end
  end
end
