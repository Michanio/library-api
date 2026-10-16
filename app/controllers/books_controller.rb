# Composes Catalog (books), Lending (status and history) and Readers (who borrowed)
# into the book endpoints of docs/openapi.yaml.
class BooksController < ApplicationController
  def index
    books = Catalog.list_books
    current_borrowings = Lending.current_borrowings(book_ids: books.map(&:id))
    readers_by_id = readers_by_id(current_borrowings.values)

    render json: {
      books: books.map { |book| BookSerializer.new(book, readers_by_id:).summary(current_borrowings[book.id]) }
    }
  end

  def show
    book = Catalog.find_book(params[:serial_number])
    history = Lending.borrowing_history(book_id: book.id)

    render json: BookSerializer.new(book, readers_by_id: readers_by_id(history)).detail(history)
  end

  def create
    book = Catalog.add_book(
      serial_number: request_body["serial_number"], title: request_body["title"], author_ids: request_body["author_ids"]
    )

    render json: BookSerializer.new(book).summary(nil), status: :created, location: book_path(book.serial_number)
  end

  # Coordinates Catalog and Lending: a borrowed book can't be deleted (ADR 0006).
  def destroy
    book = Catalog.find_book(params[:serial_number])
    if Lending.current_borrowings(book_ids: [ book.id ]).any?
      return render_problem(ProblemDetails.book_borrowed(book.serial_number))
    end

    Catalog.delete_book(book.serial_number)
    head :no_content
  end

  private
    def readers_by_id(borrowings)
      Readers.list_readers(ids: borrowings.map(&:reader_id).uniq).index_by(&:id)
    end
end
