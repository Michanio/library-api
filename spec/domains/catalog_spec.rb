require "rails_helper"

RSpec.describe Catalog do
  describe ".add_book" do
    let!(:herbert) { create(:author, name: "Frank Herbert") }
    let!(:anderson) { create(:author, name: "Kevin J. Anderson") }

    it "creates the book and returns it with its authors ordered by name" do
      book = described_class.add_book(serial_number: "000123", title: "Dune", author_ids: [ herbert.id, anderson.id ])

      expect(book).to have_attributes(serial_number: "000123", title: "Dune")
      expect(book.authors).to eq([
        Catalog::AuthorData.new(id: herbert.id, name: "Frank Herbert"),
        Catalog::AuthorData.new(id: anderson.id, name: "Kevin J. Anderson")
      ])
      expect(Catalog::Book.find(book.id).authors).to contain_exactly(herbert, anderson)
    end

    it "ignores repeated author IDs" do
      book = described_class.add_book(serial_number: "000123", title: "Dune", author_ids: [ herbert.id, herbert.id ])

      expect(book.authors.map(&:id)).to eq([ herbert.id ])
    end

    it "rejects unknown author IDs" do
      expect {
        described_class.add_book(serial_number: "000123", title: "Dune", author_ids: [ herbert.id, 0 ])
      }.to raise_error(Catalog::InvalidBook) { |error|
        expect(error.errors).to eq(author_ids: [ "contains unknown author IDs: 0" ])
      }
      expect(Catalog::Book.count).to eq(0)
    end

    it "requires at least one author ID" do
      expect {
        described_class.add_book(serial_number: "000123", title: "Dune", author_ids: [])
      }.to raise_error(Catalog::InvalidBook) { |error| expect(error.errors).to have_key(:author_ids) }
    end

    it "rejects a serial number used by a deleted book" do
      create(:book, :deleted, serial_number: "000123")

      expect {
        described_class.add_book(serial_number: "000123", title: "Dune", author_ids: [ herbert.id ])
      }.to raise_error(Catalog::InvalidBook) { |error|
        expect(error.errors).to eq(serial_number: [ "has already been taken" ])
      }
    end

    it "reports a serial number taken between validation and insert" do
      allow_any_instance_of(Catalog::Book).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)

      expect {
        described_class.add_book(serial_number: "000123", title: "Dune", author_ids: [ herbert.id ])
      }.to raise_error(Catalog::InvalidBook) { |error|
        expect(error.errors).to eq(serial_number: [ "has already been taken" ])
      }
    end
  end

  describe ".list_books" do
    it "returns active books ordered by serial number" do
      create(:book, serial_number: "000200")
      create(:book, serial_number: "000100")
      create(:book, :deleted, serial_number: "000150")

      expect(described_class.list_books.map(&:serial_number)).to eq(%w[000100 000200])
    end
  end

  describe ".find_book" do
    it "returns the book" do
      book = create(:book, serial_number: "000123")

      expect(described_class.find_book("000123")).to have_attributes(id: book.id, serial_number: "000123")
    end

    it "raises BookNotFound for an unknown serial number" do
      expect { described_class.find_book("999999") }.to raise_error(Catalog::BookNotFound)
    end

    it "raises BookNotFound for a deleted book" do
      create(:book, :deleted, serial_number: "000123")

      expect { described_class.find_book("000123") }.to raise_error(Catalog::BookNotFound)
    end
  end

  describe ".delete_book" do
    it "soft-deletes the book" do
      book = create(:book, serial_number: "000123")

      described_class.delete_book("000123")

      expect(book.reload.deleted_at).to be_present
    end

    it "raises BookNotFound for a book that's already deleted" do
      create(:book, :deleted, serial_number: "000123")

      expect { described_class.delete_book("000123") }.to raise_error(Catalog::BookNotFound)
    end
  end
end
