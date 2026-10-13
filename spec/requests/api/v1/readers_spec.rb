require "rails_helper"

RSpec.describe "Readers API", type: :request do
  it "lists readers" do
    create(:reader, card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com")

    get "/api/v1/readers"

    expect(response).to have_http_status(:ok)
    expect(json["readers"]).to eq([ { "card_number" => "100001", "full_name" => "Ada Lovelace", "email" => "ada@example.com" } ])
    expect(json["meta"]["total_count"]).to eq(1)
  end

  it "shows a reader by card number" do
    create(:reader, card_number: "100001")

    get "/api/v1/readers/100001"

    expect(response).to have_http_status(:ok)
    expect(json["card_number"]).to eq("100001")
  end

  it "creates a reader" do
    post "/api/v1/readers", params: { reader: { card_number: "100002", full_name: "Alan Turing", email: "Alan@Example.com" } }, as: :json

    expect(response).to have_http_status(:created)
    expect(json).to eq("card_number" => "100002", "full_name" => "Alan Turing", "email" => "alan@example.com")
  end

  it "rejects a duplicate email" do
    create(:reader, email: "alan@example.com")

    post "/api/v1/readers", params: { reader: { card_number: "100002", full_name: "Alan Turing", email: "alan@example.com" } }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"]).to eq([ "Email has already been taken" ])
  end
end
