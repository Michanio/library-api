# Public interface of the Catalog domain: books and their authors (ADR 0004).
# Each method delegates to a service object in app/domains/catalog/ and returns
# BookData values; the Active Record models stay inside the domain.
module Catalog
  class BookNotFound < StandardError; end

  # Raised when a book can't be saved. `errors` maps argument names to messages,
  # e.g. { serial_number: ["has already been taken"] }.
  class BookInvalid < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super("Invalid book: #{errors.inspect}")
    end
  end

  def self.add_book(serial_number:, title:, author_ids:) = AddBook.call(serial_number:, title:, author_ids:)
  def self.list_books(ids: nil) = ListBooks.call(ids:)
  def self.find_book(serial_number) = FindBook.call(serial_number)
  def self.delete_book(serial_number) = DeleteBook.call(serial_number)
end
