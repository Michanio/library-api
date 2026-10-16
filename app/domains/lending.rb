# Public interface of the Lending domain: borrowing and returning books, and the
# borrowing history (ADR 0004, ADR 0008). Each method delegates to a service object
# in app/domains/lending/ and returns BorrowingData values. Books and readers are
# referred to by ID; callers resolve them through Catalog and Readers.
module Lending
  class BookAlreadyBorrowed < StandardError; end
  class BookNotBorrowed < StandardError; end

  def self.borrow_book(book_id:, reader_id:) = BorrowBook.call(book_id:, reader_id:)
  def self.return_book(book_id:) = ReturnBook.call(book_id:)
  def self.current_borrowings(book_ids:) = CurrentBorrowings.call(book_ids:)
  def self.borrowing_history(book_id:) = BorrowingHistory.call(book_id:)
end
