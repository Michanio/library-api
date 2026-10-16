module Catalog
  # Soft-deletes a book (ADR 0006). Raises BookNotFound if no active book has the
  # serial number. Doesn't check lending; callers must not delete a borrowed book.
  class DeleteBook
    def self.call(...) = new(...).call

    def initialize(serial_number)
      @serial_number = serial_number
    end

    def call
      Book.find_kept!(@serial_number).soft_delete!
      nil
    end
  end
end
