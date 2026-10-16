module Catalog
  class Book < ApplicationRecord
    SERIAL_NUMBER_FORMAT = /\A\d{6}\z/

    has_many :book_authors, dependent: :destroy
    has_many :authors, through: :book_authors

    # Books are soft-deleted (ADR 0006). Query them through this scope; there is
    # deliberately no default_scope.
    scope :kept, -> { where(deleted_at: nil) }

    # Uniqueness covers deleted books too, so serial numbers are never reused.
    validates :serial_number, presence: true, format: { with: SERIAL_NUMBER_FORMAT }, uniqueness: true
    validates :title, presence: true, length: { maximum: 255 }
    validates :authors, presence: true

    def soft_delete!
      update!(deleted_at: Time.current)
    end
  end
end
