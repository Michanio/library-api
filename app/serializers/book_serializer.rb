# Builds the Book and BookDetail documents of docs/openapi.yaml from Catalog,
# Lending and Readers values. Timestamps are rendered in UTC (ADR 0005), although
# the app's time zone is the library's.
class BookSerializer
  # `readers_by_id` must contain the reader of every borrowing that is rendered.
  def initialize(book, readers_by_id: {})
    @book = book
    @readers_by_id = readers_by_id
  end

  # The Book document. `current_borrowing` is nil when the book is available.
  def summary(current_borrowing)
    {
      serial_number: @book.serial_number,
      title: @book.title,
      authors: @book.authors.map { |author| { id: author.id, name: author.name } },
      status: current_borrowing ? "borrowed" : "available",
      current_borrowing: current_borrowing && current_borrowing_json(current_borrowing)
    }
  end

  # The BookDetail document. `history` holds all of the book's borrowings, newest first.
  def detail(history)
    summary(history.find { |borrowing| !borrowing.returned? })
      .merge(borrowings: history.map { |borrowing| borrowing_json(borrowing) })
  end

  private
    def current_borrowing_json(borrowing)
      {
        reader: reader_json(borrowing.reader_id),
        borrowed_at: borrowing.borrowed_at.utc.iso8601,
        due_on: borrowing.due_on.iso8601
      }
    end

    def borrowing_json(borrowing)
      current_borrowing_json(borrowing).merge(returned_at: borrowing.returned_at&.utc&.iso8601)
    end

    def reader_json(reader_id)
      reader = @readers_by_id.fetch(reader_id)
      { library_card_number: reader.library_card_number, full_name: reader.full_name, email: reader.email }
    end
end
