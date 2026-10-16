module Catalog
  # A book as exposed by the Catalog public interface. Authors are ordered by name.
  BookData = Data.define(:id, :serial_number, :title, :authors) do
    def self.from(book)
      authors = book.authors.sort_by(&:name).map { |author| AuthorData.from(author) }
      new(id: book.id, serial_number: book.serial_number, title: book.title, authors:)
    end
  end
end
