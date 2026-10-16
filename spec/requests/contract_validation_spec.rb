require "rails_helper"

# Exercises ApplicationController's contract validation through a stub controller,
# routed to paths from docs/openapi.yaml. Valid requests are covered by the endpoint specs.
class ContractValidationStubController < ApplicationController
  def create = raise("an invalid request reached the action")
  def show = raise("an invalid request reached the action")
end

RSpec.describe "Contract validation", type: :request do
  around do |example|
    with_routing do |routes|
      routes.draw do
        post "/books" => "contract_validation_stub#create"
        get "/books/:serial_number" => "contract_validation_stub#show"
      end
      example.run
    end
  end

  it "rejects a body that doesn't match the contract with a problem details response" do
    post "/books", params: { title: "Dune" }.to_json, headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
    expect(response.media_type).to eq("application/problem+json")
    expect(response.parsed_body).to include(
      "type" => "urn:library-api:problem:invalid-request",
      "status" => 400,
      "errors" => contain_exactly(
        { "pointer" => "/serial_number", "detail" => "is required" },
        { "pointer" => "/author", "detail" => "is required" }
      )
    )
  end

  it "rejects an invalid path parameter" do
    get "/books/12345"

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body).to include("type" => "urn:library-api:problem:invalid-request")
  end
end
