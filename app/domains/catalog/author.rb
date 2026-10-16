module Catalog
  # An author's authority record (ADR 0007): one record per name, linked to books.
  class Author < ApplicationRecord
    has_many :book_authors, dependent: :restrict_with_exception
    has_many :books, through: :book_authors

    normalizes :name, with: ->(name) { name.squish }

    validates :name, presence: true, uniqueness: { case_sensitive: false }
  end
end
