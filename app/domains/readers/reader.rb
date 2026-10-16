module Readers
  class Reader < ApplicationRecord
    LIBRARY_CARD_NUMBER_FORMAT = /\A\d{6}\z/

    normalizes :full_name, with: ->(full_name) { full_name.squish }
    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :library_card_number, presence: true, format: { with: LIBRARY_CARD_NUMBER_FORMAT }, uniqueness: true
    validates :full_name, presence: true, length: { maximum: 255 }
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  end
end
