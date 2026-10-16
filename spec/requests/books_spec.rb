require "rails_helper"

# Every response is also validated against docs/openapi.yaml by the contract test
# integration (spec/support/openapi_first.rb).
RSpec.describe "Books", type: :request do
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:herbert) { create(:author, name: "Frank Herbert") }
  let(:reader) { create(:reader, library_card_number: "004217", full_name: "Jane Doe", email: "jane@example.com") }

  describe "GET /books" do
    it "lists active books with their status and current borrowing" do
      create(:book, serial_number: "000100", title: "Dune", authors: [ herbert ])
      borrowed = create(:book, serial_number: "000200")
      create(:book, :deleted, serial_number: "000150")
      travel_to Time.zone.local(2026, 3, 1, 10) do
        create(:borrowing, book_id: borrowed.id, reader_id: reader.id, borrowed_at: Time.current)
      end

      get "/books"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["books"]).to eq([
        {
          "serial_number" => "000100", "title" => "Dune",
          "authors" => [ { "id" => herbert.id, "name" => "Frank Herbert" } ],
          "status" => "available", "current_borrowing" => nil
        },
        {
          "serial_number" => "000200", "title" => borrowed.title,
          "authors" => [ { "id" => borrowed.authors.first.id, "name" => borrowed.authors.first.name } ],
          "status" => "borrowed",
          "current_borrowing" => {
            "reader" => { "library_card_number" => "004217", "full_name" => "Jane Doe", "email" => "jane@example.com" },
            "borrowed_at" => "2026-03-01T09:00:00Z",
            "due_on" => "2026-03-31"
          }
        }
      ])
    end

    it "answers HEAD like GET, without a body" do
      create(:book)

      head "/books"

      expect(response).to have_http_status(:ok)
      expect(response.body).to be_empty
    end

    it "returns an empty list when there are no books" do
      get "/books"

      expect(response.parsed_body).to eq("books" => [])
    end
  end

  describe "POST /books" do
    it "adds a book" do
      post "/books", params: { serial_number: "000123", title: "Dune", author_ids: [ herbert.id ] }.to_json, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.location).to end_with("/books/000123")
      expect(response.parsed_body).to include(
        "serial_number" => "000123", "status" => "available", "current_borrowing" => nil,
        "authors" => [ { "id" => herbert.id, "name" => "Frank Herbert" } ]
      )
    end

    it "rejects a body that doesn't match the contract" do
      post "/books", params: { serial_number: "123", title: "Dune", author_ids: [ herbert.id ] }.to_json, headers: json_headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"]).to contain_exactly(a_hash_including("pointer" => "/serial_number"))
    end

    it "rejects a serial number that's already taken" do
      create(:book, :deleted, serial_number: "000123")

      post "/books", params: { serial_number: "000123", title: "Dune", author_ids: [ herbert.id ] }.to_json, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq("application/problem+json")
      expect(response.parsed_body).to include(
        "type" => "urn:library-api:problem:validation-failed",
        "errors" => [ { "pointer" => "/serial_number", "detail" => "has already been taken" } ]
      )
    end

    it "rejects unknown author IDs" do
      post "/books", params: { serial_number: "000123", title: "Dune", author_ids: [ 0 ] }.to_json, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq([ { "pointer" => "/author_ids", "detail" => "contains unknown author IDs: 0" } ])
    end
  end

  describe "GET /books/:serial_number" do
    it "shows the book with its full borrowing history, newest first" do
      book = create(:book, serial_number: "000123", title: "Dune", authors: [ herbert ])
      other_reader = create(:reader, library_card_number: "000001")
      create(:borrowing, :returned, book_id: book.id, reader_id: other_reader.id, borrowed_at: Time.utc(2026, 1, 10, 12))
      create(:borrowing, book_id: book.id, reader_id: reader.id, borrowed_at: Time.utc(2026, 3, 1, 9))

      get "/books/000123"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include("serial_number" => "000123", "status" => "borrowed")
      expect(body["current_borrowing"]).to include("borrowed_at" => "2026-03-01T09:00:00Z", "due_on" => "2026-03-31")
      expect(body["borrowings"]).to match([
        a_hash_including("reader" => a_hash_including("library_card_number" => "004217"), "returned_at" => nil),
        a_hash_including(
          "reader" => a_hash_including("library_card_number" => "000001"),
          "borrowed_at" => "2026-01-10T12:00:00Z", "due_on" => "2026-02-09", "returned_at" => "2026-01-10T13:00:00Z"
        )
      ])
    end

    it "shows an available book with an empty history" do
      create(:book, serial_number: "000123")

      get "/books/000123"

      expect(response.parsed_body).to include("status" => "available", "current_borrowing" => nil, "borrowings" => [])
    end

    it "returns 404 for a deleted book" do
      create(:book, :deleted, serial_number: "000123")

      get "/books/000123"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq(
        "type" => "about:blank", "title" => "Not Found", "status" => 404, "detail" => "Book 000123 not found."
      )
    end

    it "rejects a serial number that isn't six digits" do
      get "/books/123"

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /books/:serial_number" do
    it "soft-deletes the book" do
      book = create(:book, serial_number: "000123")
      create(:borrowing, :returned, book_id: book.id)

      delete "/books/000123"

      expect(response).to have_http_status(:no_content)
      expect(book.reload.deleted_at).to be_present
      expect(Lending::Borrowing.where(book_id: book.id)).to exist
    end

    it "refuses to delete a borrowed book" do
      book = create(:book, serial_number: "000123")
      create(:borrowing, book_id: book.id)

      delete "/books/000123"

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to include("type" => "urn:library-api:problem:book-borrowed")
      expect(book.reload.deleted_at).to be_nil
    end

    it "returns 404 for a book that's already deleted" do
      create(:book, :deleted, serial_number: "000123")

      delete "/books/000123"

      expect(response).to have_http_status(:not_found)
    end

    it "rejects a serial number that isn't six digits" do
      delete "/books/abc"

      expect(response).to have_http_status(:bad_request)
    end
  end
end
