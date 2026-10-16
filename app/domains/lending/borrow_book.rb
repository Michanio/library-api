module Lending
  # Lends a book to a reader for Borrowing::LOAN_PERIOD, starting now. Raises
  # BookAlreadyBorrowed if the book is out. The book and reader must exist;
  # callers look them up through Catalog and Readers first.
  class BorrowBook
    def self.call(...) = new(...).call

    def initialize(book_id:, reader_id:)
      @book_id = book_id
      @reader_id = reader_id
    end

    def call
      raise_already_borrowed if Borrowing.current.exists?(book_id: @book_id)

      borrowed_at = Time.current
      borrowing = Borrowing.create!(
        book_id: @book_id, reader_id: @reader_id, borrowed_at:, due_on: Borrowing.due_on_for(borrowed_at)
      )
      BorrowingData.from(borrowing)
    rescue ActiveRecord::RecordNotUnique
      # Another request lent the book between the check and the insert.
      raise_already_borrowed
    end

    private
      def raise_already_borrowed
        raise BookAlreadyBorrowed, "Book #{@book_id} is already borrowed"
      end
  end
end
