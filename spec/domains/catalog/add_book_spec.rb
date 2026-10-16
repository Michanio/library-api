require "rails_helper"

RSpec.describe Catalog::AddBook do
  let!(:herbert) { create(:author, name: "Frank Herbert") }
  let!(:anderson) { create(:author, name: "Kevin J. Anderson") }

  def add_book(serial_number: "000123", title: "Dune", author_ids: [ herbert.id ])
    described_class.call(serial_number:, title:, author_ids:)
  end

  it "creates the book and returns it with its authors ordered by name" do
    book = add_book(author_ids: [ anderson.id, herbert.id ])

    expect(book).to have_attributes(serial_number: "000123", title: "Dune")
    expect(book.authors).to eq([
      Catalog::AuthorData.new(id: herbert.id, name: "Frank Herbert"),
      Catalog::AuthorData.new(id: anderson.id, name: "Kevin J. Anderson")
    ])
    expect(Catalog::Book.find(book.id).authors).to contain_exactly(herbert, anderson)
  end

  it "ignores repeated author IDs" do
    book = add_book(author_ids: [ herbert.id, herbert.id ])

    expect(book.authors.map(&:id)).to eq([ herbert.id ])
  end

  it "rejects unknown author IDs" do
    expect { add_book(author_ids: [ herbert.id, 0 ]) }.to raise_error(Catalog::BookInvalid) { |error|
      expect(error.errors).to eq(author_ids: [ "contains unknown author IDs: 0" ])
    }
    expect(Catalog::Book.count).to eq(0)
  end

  it "requires at least one author ID" do
    expect { add_book(author_ids: []) }.to raise_error(Catalog::BookInvalid) { |error|
      expect(error.errors).to eq(author_ids: [ "can't be blank" ])
    }
  end

  it "reports invalid fields under their argument names" do
    expect { add_book(serial_number: "12345", title: "") }.to raise_error(Catalog::BookInvalid) { |error|
      expect(error.errors.keys).to contain_exactly(:serial_number, :title)
    }
  end

  it "rejects a serial number used by a deleted book" do
    create(:book, :deleted, serial_number: "000123")

    expect { add_book }.to raise_error(Catalog::BookInvalid) { |error|
      expect(error.errors).to eq(serial_number: [ "has already been taken" ])
    }
  end

  it "reports a serial number taken between validation and insert" do
    allow_any_instance_of(Catalog::Book).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)

    expect { add_book }.to raise_error(Catalog::BookInvalid) { |error|
      expect(error.errors).to eq(serial_number: [ "has already been taken" ])
    }
  end
end
