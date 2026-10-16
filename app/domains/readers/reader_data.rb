module Readers
  # A reader as exposed by the Readers public interface.
  ReaderData = Data.define(:id, :library_card_number, :full_name, :email) do
    def self.from(reader)
      new(id: reader.id, library_card_number: reader.library_card_number, full_name: reader.full_name, email: reader.email)
    end
  end
end
