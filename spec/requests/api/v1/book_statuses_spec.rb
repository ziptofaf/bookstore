require "rails_helper"

RSpec.describe "Book status API", type: :request do
  let!(:book) { create(:book, serial_number: "000001") }
  let!(:reader) { create(:reader, card_number: "100001") }

  def update_status(params)
    patch "/api/v1/books/000001/status", params: params, as: :json
  end

  it "borrows an available book" do
    travel_to Time.zone.local(2026, 10, 11, 9) do
      update_status(status: "borrowed", card_number: "100001")
    end

    expect(response).to have_http_status(:ok)
    expect(json).to include("status" => "borrowed",
                            "current_borrowing" => include("due_date" => "2026-11-10",
                                                           "reader" => include("card_number" => "100001")))
  end

  it "returns a borrowed book" do
    create(:borrowing, book: book, reader: reader, borrowed_at: 2.days.ago)

    update_status(status: "available")

    expect(response).to have_http_status(:ok)
    expect(json).to include("status" => "available", "current_borrowing" => nil)
  end

  it "passes the request to the status service" do
    allow(Books::UpdateStatus).to receive(:call)

    update_status(status: "borrowed", card_number: "100001")

    expect(Books::UpdateStatus).to have_received(:call).with(book: book, status: "borrowed", card_number: "100001")
  end

  it "returns 409 when the book is already borrowed" do
    create(:borrowing, book: book)

    update_status(status: "borrowed", card_number: "100001")

    expect(response).to have_http_status(:conflict)
    expect(json["errors"]).to eq([ "Book is already borrowed" ])
  end

  it "returns 409 when returning a book that is not borrowed" do
    update_status(status: "available")

    expect(response).to have_http_status(:conflict)
    expect(json["errors"]).to eq([ "Book is not borrowed" ])
  end

  it "returns 422 for an unknown reader" do
    update_status(status: "borrowed", card_number: "999999")

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"]).to eq([ 'Reader with card number "999999" not found' ])
  end

  it "returns 422 for an unknown status" do
    update_status(status: "lost")

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns 422 without a status" do
    update_status(card_number: "100001")

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"]).to eq([ "Status must be one of: available, borrowed" ])
  end

  it "returns 404 for an unknown book" do
    patch "/api/v1/books/999999/status", params: { status: "available" }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
