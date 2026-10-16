require "rails_helper"

RSpec.describe Lending::Borrowing, type: :model do
  it { is_expected.to validate_presence_of(:book_id) }
  it { is_expected.to validate_presence_of(:reader_id) }
  it { is_expected.to validate_presence_of(:borrowed_at) }
  it { is_expected.to validate_presence_of(:due_on) }

  describe ".current" do
    it "returns borrowings that haven't been returned" do
      current = create(:borrowing)
      create(:borrowing, :returned)

      expect(described_class.current).to contain_exactly(current)
    end
  end

  describe ".due_on_for" do
    it "is 30 days after the borrow date" do
      expect(described_class.due_on_for(Time.zone.local(2026, 3, 1, 12))).to eq(Date.new(2026, 3, 31))
    end

    it "uses the library's calendar day, not the UTC one" do
      # 00:30 on 2 March in Warsaw is still 1 March in UTC.
      borrowed_at = Time.find_zone("Europe/Warsaw").local(2026, 3, 2, 0, 30)

      expect(described_class.due_on_for(borrowed_at.utc)).to eq(Date.new(2026, 4, 1))
    end
  end

  describe "database constraints" do
    it "allows only one current borrowing per book" do
      borrowing = create(:borrowing)

      expect { create(:borrowing, book_id: borrowing.book_id) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows any number of returned borrowings per book" do
      borrowing = create(:borrowing, :returned)

      expect { create(:borrowing, :returned, book_id: borrowing.book_id) }.not_to raise_error
    end

    it "rejects a return before the borrow" do
      borrowing = create(:borrowing)

      expect { borrowing.update!(returned_at: borrowing.borrowed_at - 1.minute) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
