require "rails_helper"

RSpec.describe "Books API", type: :request do
  describe "GET /api/v1/books" do
    let!(:available) { create(:book, serial_number: "000001", title: "Dune") }
    let!(:borrowing) { create(:borrowing, book: create(:book, serial_number: "000002"), due_date: Date.new(2026, 11, 10)) }

    it "lists books with their availability" do
      get "/api/v1/books"

      expect(response).to have_http_status(:ok)
      expect(json["books"]).to match([
        include("serial_number" => "000001", "title" => "Dune", "status" => "available", "current_borrowing" => nil),
        include("serial_number" => "000002", "status" => "borrowed",
                "current_borrowing" => include("due_date" => "2026-11-10",
                                               "reader" => include("card_number" => borrowing.reader.card_number)))
      ])
      expect(json["meta"]).to eq("page" => 1, "per_page" => 25, "total_count" => 2)
    end

    it "filters by status" do
      get "/api/v1/books", params: { status: "borrowed" }

      expect(json["books"].pluck("serial_number")).to eq([ "000002" ])
      expect(json["meta"]["total_count"]).to eq(1)
    end

    it "paginates" do
      get "/api/v1/books", params: { page: 2, per_page: 1 }

      expect(json["books"].pluck("serial_number")).to eq([ "000002" ])
      expect(json["meta"]).to eq("page" => 2, "per_page" => 1, "total_count" => 2)
    end

    it "does not run a query per book" do
      create_list(:book, 3, :borrowed)
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get "/api/v1/books" }

      expect(queries.size).to be <= 4
    end
  end

  describe "GET /api/v1/books/:serial_number" do
    let(:book) { create(:book, serial_number: "000007") }
    let(:old_reader) { create(:reader, full_name: "Alan Turing") }
    let(:current_reader) { create(:reader, full_name: "Grace Hopper") }

    before do
      create(:borrowing, book: book, reader: old_reader,
                         borrowed_at: Time.zone.local(2026, 1, 1, 10), returned_at: Time.zone.local(2026, 1, 20, 10))
      create(:borrowing, book: book, reader: current_reader, borrowed_at: Time.zone.local(2026, 10, 1, 10))
    end

    it "returns the book with its full borrowing history, newest first" do
      get "/api/v1/books/000007"

      expect(response).to have_http_status(:ok)
      expect(json).to include("serial_number" => "000007", "status" => "borrowed")
      expect(json["borrowings"]).to match([
        include("borrowed_at" => "2026-10-01T10:00:00.000Z", "due_date" => "2026-10-31", "returned_at" => nil,
                "reader" => include("full_name" => "Grace Hopper")),
        include("borrowed_at" => "2026-01-01T10:00:00.000Z", "returned_at" => "2026-01-20T10:00:00.000Z",
                "reader" => { "card_number" => old_reader.card_number, "full_name" => "Alan Turing",
                              "email" => old_reader.email })
      ])
    end

    it "returns 404 for an unknown book" do
      get "/api/v1/books/999999"

      expect(response).to have_http_status(:not_found)
      expect(json).to eq("errors" => [ "Book not found" ])
    end
  end

  describe "POST /api/v1/books" do
    it "creates a book" do
      expect {
        post "/api/v1/books", params: { book: { serial_number: "123456", title: "Solaris", author: "Stanisław Lem" } }, as: :json
      }.to change(Book, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.location).to end_with("/api/v1/books/123456")
      expect(json).to include("serial_number" => "123456", "title" => "Solaris", "status" => "available")
    end

    it "rejects invalid attributes" do
      create(:book, serial_number: "123456")

      post "/api/v1/books", params: { book: { serial_number: "123456", title: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to include("Serial number has already been taken", "Title can't be blank", "Author can't be blank")
    end

    it "requires the book payload" do
      post "/api/v1/books", params: { name: "Solaris" }, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /api/v1/books/:serial_number" do
    it "deletes an available book" do
      create(:book, serial_number: "000010")

      expect { delete "/api/v1/books/000010" }.to change(Book, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "refuses to delete a borrowed book" do
      create(:book, :borrowed, serial_number: "000010")

      expect { delete "/api/v1/books/000010" }.not_to change(Book, :count)
      expect(response).to have_http_status(:conflict)
      expect(json["errors"]).to eq([ "Cannot delete a book that is currently borrowed" ])
    end
  end
end
