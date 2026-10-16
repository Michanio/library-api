# Public interface of the Catalog domain: books and their authors (ADR 0004).
# Returns BookData values; the Active Record models stay inside the domain.
module Catalog
  class BookNotFound < StandardError; end

  # Raised when a book can't be saved. `errors` maps argument names to messages,
  # e.g. { serial_number: ["has already been taken"] }.
  class InvalidBook < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super("Invalid book: #{errors.inspect}")
    end
  end

  # Raises InvalidBook if a field is invalid, the serial number is taken (by any
  # book, deleted ones included) or an author ID matches no author.
  def self.add_book(serial_number:, title:, author_ids:)
    author_ids = author_ids.uniq
    authors = Author.where(id: author_ids).to_a
    book = Book.new(serial_number:, title:, authors:)

    book.validate
    unknown_ids = author_ids - authors.map(&:id)
    book.errors.add(:author_ids, "contains unknown author IDs: #{unknown_ids.join(", ")}") if unknown_ids.any?
    book.errors.delete(:authors) if author_ids.any? # already reported as unknown IDs
    raise InvalidBook, invalid_book_errors(book) if book.errors.any?

    book.save!
    BookData.from(book)
  rescue ActiveRecord::RecordNotUnique
    # Another request took the serial number between validation and insert.
    raise InvalidBook, { serial_number: [ "has already been taken" ] }
  end

  # Active (not deleted) books, ordered by serial number.
  def self.list_books
    Book.kept.includes(:authors).order(:serial_number).map { |book| BookData.from(book) }
  end

  # Raises BookNotFound if no active book has the serial number.
  def self.find_book(serial_number)
    BookData.from(find_kept_book(serial_number))
  end

  # Soft-deletes the book (ADR 0006). Raises BookNotFound if no active book has the
  # serial number. Doesn't check lending; callers must not delete a borrowed book.
  def self.delete_book(serial_number)
    find_kept_book(serial_number).soft_delete!
    nil
  end

  def self.find_kept_book(serial_number)
    Book.kept.includes(:authors).find_by(serial_number:) or
      raise BookNotFound, "Book #{serial_number} not found"
  end
  private_class_method :find_kept_book

  # Reports errors under the interface's argument names: `authors` is `author_ids`.
  def self.invalid_book_errors(book)
    book.errors.to_hash.transform_keys { |key| key == :authors ? :author_ids : key }
  end
  private_class_method :invalid_book_errors
end
