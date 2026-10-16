module Catalog
  # Active (not deleted) books, ordered by serial number.
  class ListBooks
    def self.call = new.call

    def call
      Book.kept.includes(:authors).order(:serial_number).map { |book| BookData.from(book) }
    end
  end
end
