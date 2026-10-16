module Lending
  # All borrowings of a book, the current one included, newest first.
  class BorrowingHistory
    def self.call(...) = new(...).call

    def initialize(book_id:)
      @book_id = book_id
    end

    def call
      Borrowing.where(book_id: @book_id).order(borrowed_at: :desc, id: :desc).map { |borrowing| BorrowingData.from(borrowing) }
    end
  end
end
