require "rails_helper"

RSpec.describe Catalog::Book, type: :model do
  subject { build(:book) }

  it { is_expected.to validate_presence_of(:serial_number) }
  it { is_expected.to validate_uniqueness_of(:serial_number).ignoring_case_sensitivity }
  it { is_expected.to allow_value("000123").for(:serial_number) }
  it { is_expected.not_to allow_values("12345", "1234567", "12a456", "123456\n").for(:serial_number) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_length_of(:title).is_at_most(255) }

  it "requires at least one author" do
    book = build(:book, authors: [])

    expect(book).not_to be_valid
    expect(book.errors[:authors]).to be_present
  end

  it "keeps a deleted book's serial number reserved" do
    create(:book, :deleted, serial_number: "000123")

    expect(build(:book, serial_number: "000123")).not_to be_valid
  end

  describe ".kept" do
    it "excludes deleted books" do
      kept = create(:book)
      create(:book, :deleted)

      expect(described_class.kept).to contain_exactly(kept)
    end
  end

  describe "#soft_delete!" do
    it "sets deleted_at and keeps the row" do
      book = create(:book)

      expect { book.soft_delete! }.not_to change(described_class, :count)
      expect(book.reload.deleted_at).to be_present
    end
  end
end
