module Lending
  # A borrowing as exposed by the Lending public interface. `returned_at` is nil
  # while the book is out.
  BorrowingData = Data.define(:id, :book_id, :reader_id, :borrowed_at, :due_on, :returned_at) do
    def self.from(borrowing)
      new(
        id: borrowing.id, book_id: borrowing.book_id, reader_id: borrowing.reader_id,
        borrowed_at: borrowing.borrowed_at, due_on: borrowing.due_on, returned_at: borrowing.returned_at
      )
    end

    def returned? = !returned_at.nil?
  end
end
