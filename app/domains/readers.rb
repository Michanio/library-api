# Public interface of the Readers domain: library card holders (ADR 0004).
# Each method delegates to a service object in app/domains/readers/ and returns
# ReaderData values; the Active Record model stays inside the domain.
module Readers
  class ReaderNotFound < StandardError; end

  def self.find_reader(library_card_number) = FindReader.call(library_card_number)
  def self.list_readers(ids:) = ListReaders.call(ids:)
end
