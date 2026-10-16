module Readers
  # Raises ReaderNotFound if no reader has the library card number.
  class FindReader
    def self.call(...) = new(...).call

    def initialize(library_card_number)
      @library_card_number = library_card_number
    end

    def call
      reader = Reader.find_by(library_card_number: @library_card_number) or
        raise ReaderNotFound, "Reader #{@library_card_number} not found"
      ReaderData.from(reader)
    end
  end
end
