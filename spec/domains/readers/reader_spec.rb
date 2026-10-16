require "rails_helper"

RSpec.describe Readers::Reader, type: :model do
  subject { build(:reader) }

  it { is_expected.to validate_presence_of(:library_card_number) }
  it { is_expected.to validate_uniqueness_of(:library_card_number).ignoring_case_sensitivity }
  it { is_expected.to allow_value("004217").for(:library_card_number) }
  it { is_expected.not_to allow_values("4217", "1234567", "12a456", "123456\n").for(:library_card_number) }
  it { is_expected.to validate_presence_of(:full_name) }
  it { is_expected.to validate_length_of(:full_name).is_at_most(255) }
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.not_to allow_values("jane", "jane@", "@example.com").for(:email) }

  it "normalizes the email and full name" do
    reader = build(:reader, email: "  Jane.Doe@Example.COM ", full_name: " Jane   Doe ")

    expect(reader).to have_attributes(email: "jane.doe@example.com", full_name: "Jane Doe")
  end

  it "treats emails differing only in case as the same" do
    create(:reader, email: "jane.doe@example.com")

    reader = build(:reader, email: "Jane.Doe@example.com")
    expect(reader).not_to be_valid
    expect(reader.errors[:email]).to include("has already been taken")
  end
end
