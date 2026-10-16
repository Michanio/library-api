module Readers
  # Readers with the given IDs, in one query, ordered by ID. IDs that match no
  # reader are left out.
  class ListReaders
    def self.call(...) = new(...).call

    def initialize(ids:)
      @ids = ids
    end

    def call
      Reader.where(id: @ids).order(:id).map { |reader| ReaderData.from(reader) }
    end
  end
end
