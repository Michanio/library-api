require "rails_helper"

RSpec.describe Readers::ListReaders do
  it "returns the readers with the given IDs, ordered by ID" do
    first, second, _other = create_list(:reader, 3)

    expect(described_class.call(ids: [ second.id, first.id ]).map(&:id)).to eq([ first.id, second.id ])
  end

  it "leaves out IDs that match no reader" do
    reader = create(:reader)

    expect(described_class.call(ids: [ reader.id, 0 ]).map(&:id)).to eq([ reader.id ])
  end

  it "returns an empty list for no IDs" do
    expect(described_class.call(ids: [])).to eq([])
  end
end
