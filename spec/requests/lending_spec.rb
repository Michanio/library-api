require "rails_helper"

# Every response is also validated against docs/openapi.yaml by the contract test
# integration (spec/support/openapi_first.rb).
RSpec.describe "Lending", type: :request do
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let!(:book) { create(:book, serial_number: "000123") }
  let!(:reader) { create(:reader, library_card_number: "004217", full_name: "Jane Doe", email: "jane@example.com") }

  def borrow(serial_number: "000123", library_card_number: "004217")
    post "/books/#{serial_number}/borrow", params: { library_card_number: }.to_json, headers: json_headers
  end

  describe "POST /books/:serial_number/borrow" do
    it "lends the book to the reader for 30 days" do
      travel_to Time.zone.local(2026, 3, 1, 10) do
        borrow
      end

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "serial_number" => "000123",
        "status" => "borrowed",
        "current_borrowing" => {
          "reader" => { "library_card_number" => "004217", "full_name" => "Jane Doe", "email" => "jane@example.com" },
          "borrowed_at" => "2026-03-01T09:00:00Z",
          "due_on" => "2026-03-31"
        }
      )
      expect(Lending::Borrowing.current.where(book_id: book.id, reader_id: reader.id)).to exist
    end

    it "rejects a body without a library card number" do
      post "/books/000123/borrow", params: {}.to_json, headers: json_headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"]).to eq([ { "pointer" => "/library_card_number", "detail" => "is required" } ])
    end

    it "returns 404 for a deleted book" do
      book.update!(deleted_at: Time.current)

      borrow

      expect(response).to have_http_status(:not_found)
    end

    it "refuses to lend a book that's already borrowed" do
      create(:borrowing, book_id: book.id)

      borrow

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to include(
        "type" => "urn:library-api:problem:book-borrowed", "detail" => "Book 000123 is currently borrowed."
      )
    end

    it "rejects a library card number that matches no reader" do
      borrow(library_card_number: "999999")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include(
        "type" => "urn:library-api:problem:validation-failed",
        "errors" => [ { "pointer" => "/library_card_number", "detail" => "does not match any reader" } ]
      )
      expect(Lending::Borrowing.count).to eq(0)
    end
  end

  describe "POST /books/:serial_number/return" do
    it "records the return and makes the book available" do
      borrowing = create(:borrowing, book_id: book.id, reader_id: reader.id)

      post "/books/000123/return"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("status" => "available", "current_borrowing" => nil)
      expect(borrowing.reload.returned_at).to be_present
    end

    it "rejects a serial number that isn't six digits" do
      post "/books/12345/return"

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 404 for an unknown book" do
      post "/books/999999/return"

      expect(response).to have_http_status(:not_found)
    end

    it "refuses to return a book that isn't borrowed" do
      post "/books/000123/return"

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to include(
        "type" => "urn:library-api:problem:book-not-borrowed", "detail" => "Book 000123 is not currently borrowed."
      )
    end
  end

  it "lends a returned book again and keeps the history" do
    borrow
    post "/books/000123/return"
    borrow(library_card_number: create(:reader, library_card_number: "000001").library_card_number)

    get "/books/000123"

    expect(response.parsed_body["borrowings"].map { |b| b.dig("reader", "library_card_number") }).to eq(%w[000001 004217])
  end
end
