require "rails_helper"

RSpec.describe Lending::CurrentBorrowings do
  it "maps the given books that are out to their current borrowing" do
    out = create(:borrowing)
    returned = create(:borrowing, :returned)
    other_book_out = create(:borrowing)

    result = described_class.call(book_ids: [ out.book_id, returned.book_id ])

    expect(result.keys).to eq([ out.book_id ])
    expect(result[out.book_id]).to have_attributes(id: out.id, returned_at: nil)
    expect(result).not_to have_key(other_book_out.book_id)
  end

  it "returns an empty hash for no books" do
    expect(described_class.call(book_ids: [])).to eq({})
  end
end
