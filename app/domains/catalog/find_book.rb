module Catalog
  # Raises BookNotFound if no active book has the serial number.
  class FindBook
    def self.call(...) = new(...).call

    def initialize(serial_number)
      @serial_number = serial_number
    end

    def call
      BookData.from(Book.find_active!(@serial_number))
    end
  end
end
