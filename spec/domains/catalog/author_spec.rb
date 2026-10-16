require "rails_helper"

RSpec.describe Catalog::Author, type: :model do
  subject { build(:author) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).case_insensitive }

  it "squishes the name" do
    expect(build(:author, name: "  Frank   Herbert ").name).to eq("Frank Herbert")
  end

  it "can't be deleted while linked to a book" do
    book = create(:book)

    expect { book.authors.first.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end
