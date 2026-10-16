module Lending
  # A book lent to a reader. Refers to Catalog and Readers records by ID only (ADR 0004).
  class Borrowing < ApplicationRecord
    LOAN_PERIOD = 30.days

    # Borrowings whose book hasn't been returned yet. A book has at most one (ADR 0008).
    scope :current, -> { where(returned_at: nil) }

    validates :book_id, :reader_id, :borrowed_at, :due_on, presence: true

    # Due dates are days in the library's time zone (config.time_zone).
    def self.due_on_for(borrowed_at)
      borrowed_at.in_time_zone.to_date + LOAN_PERIOD
    end
  end
end
