module Lending
  # Records the return of a book by closing its current borrowing. Raises
  # BookNotBorrowed if the book isn't out.
  class ReturnBook
    def self.call(...) = new(...).call

    def initialize(book_id:)
      @book_id = book_id
    end

    def call
      Borrowing.transaction do
        # The row lock makes a concurrent return wait, then find nothing to close.
        borrowing = Borrowing.current.lock.find_by(book_id: @book_id) or
          raise BookNotBorrowed, "Book #{@book_id} is not borrowed"
        borrowing.update!(returned_at: Time.current)
        BorrowingData.from(borrowing)
      end
    end
  end
end
