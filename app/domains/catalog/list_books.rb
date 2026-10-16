module Catalog
  # Active (not deleted) books, ordered by serial number. With `ids`, only the books
  # with those IDs.
  class ListBooks
    def self.call(...) = new(...).call

    def initialize(ids: nil)
      @ids = ids
    end

    def call
      books = Book.active.includes(:authors).order(:serial_number)
      books = books.where(id: @ids) unless @ids.nil?
      books.map { |book| BookData.from(book) }
    end
  end
end
