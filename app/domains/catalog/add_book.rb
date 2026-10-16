module Catalog
  # Adds a book linked to existing authors. Raises BookInvalid if a field is
  # invalid, the serial number is taken (by any book, deleted ones included) or
  # an author ID matches no author.
  class AddBook
    def self.call(...) = new(...).call

    def initialize(serial_number:, title:, author_ids:)
      @serial_number = serial_number
      @title = title
      @author_ids = author_ids.uniq
    end

    def call
      authors = Author.where(id: @author_ids).to_a
      book = Book.new(serial_number: @serial_number, title: @title, authors:)
      errors = validation_errors(book, authors)
      raise BookInvalid, errors if errors.any?

      book.save!
      BookData.from(book)
    rescue ActiveRecord::RecordNotUnique
      # Another request took the serial number between validation and insert.
      raise BookInvalid, { serial_number: [ "has already been taken" ] }
    end

    private
      # Reports errors under the argument names: `authors` is `author_ids`.
      def validation_errors(book, authors)
        book.validate
        unknown_ids = @author_ids - authors.map(&:id)
        book.errors.add(:author_ids, "contains unknown author IDs: #{unknown_ids.join(", ")}") if unknown_ids.any?
        book.errors.delete(:authors) if @author_ids.any? # already reported as unknown IDs
        book.errors.to_hash.transform_keys { |key| key == :authors ? :author_ids : key }
      end
  end
end
