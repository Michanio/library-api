# The borrow and return action endpoints (ADR 0005). Resolves the book through
# Catalog and the reader through Readers, then changes the status through Lending.
class LendingController < ApplicationController
  rescue_from Readers::ReaderNotFound do
    render_problem ProblemDetails.validation_failed(
      "The book could not be borrowed.", { library_card_number: [ "does not match any reader" ] }
    )
  end

  rescue_from Lending::BookAlreadyBorrowed do
    render_problem ProblemDetails.book_borrowed(params[:serial_number])
  end

  rescue_from Lending::BookNotBorrowed do
    render_problem ProblemDetails.book_not_borrowed(params[:serial_number])
  end

  def borrow
    book = Catalog.find_book(params[:serial_number])
    reader = Readers.find_reader(request_body["library_card_number"])
    borrowing = Lending.borrow_book(book_id: book.id, reader_id: reader.id)

    render json: BookSerializer.new(book, readers_by_id: { reader.id => reader }).summary(borrowing)
  end

  def return_book
    book = Catalog.find_book(params[:serial_number])
    Lending.return_book(book_id: book.id)

    render json: BookSerializer.new(book).summary(nil)
  end
end
