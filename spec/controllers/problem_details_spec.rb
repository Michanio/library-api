require "rails_helper"

RSpec.describe ProblemDetails do
  describe ".from_contract_failure" do
    def failure_for(path, method: "POST", body: nil, content_type: "application/json")
      env = Rack::MockRequest.env_for(path, method:, input: body.to_s, "CONTENT_TYPE" => content_type)
      OpenapiFirst[:default].validate_request(Rack::Request.new(env)).error
    end

    def problem_for(...)
      described_class.from_contract_failure(failure_for(...)).to_h
    end

    it "returns an invalid-request problem with one error per missing field" do
      problem = problem_for("/books", body: { title: "Dune" }.to_json)

      expect(problem).to include(type: "urn:library-api:problem:invalid-request", title: "Invalid request", status: 400)
      expect(problem[:errors]).to contain_exactly(
        { pointer: "/serial_number", detail: "is required" },
        { pointer: "/author_ids", detail: "is required" }
      )
    end

    it "points at fields that don't match their schema" do
      problem = problem_for("/books", body: { serial_number: "12345a", title: "Dune", author_ids: [ 1 ] }.to_json)

      expect(problem[:errors]).to contain_exactly(
        { pointer: "/serial_number", detail: a_string_including("does not match pattern") }
      )
    end

    it "rejects a serial number with a trailing newline" do
      problem = problem_for("/books", body: { serial_number: "123456\n", title: "Dune", author_ids: [ 1 ] }.to_json)

      expect(problem[:errors]).to contain_exactly(a_hash_including(pointer: "/serial_number"))
    end

    it "reports fields the contract doesn't allow" do
      problem = problem_for("/books", body: { serial_number: "000123", title: "Dune", author_ids: [ 1 ], isbn: "x" }.to_json)

      expect(problem[:errors]).to contain_exactly({ pointer: "/isbn", detail: "is not allowed" })
    end

    it "explains a body that isn't valid JSON without field errors" do
      problem = problem_for("/books", body: '{"serial_number":')

      expect(problem).to include(status: 400, detail: "Failed to parse request body as JSON")
      expect(problem).not_to have_key(:errors)
    end

    it "explains an invalid path parameter without field errors" do
      problem = problem_for("/books/abc", method: "GET")

      expect(problem).to include(status: 400, detail: a_string_including("/serial_number"))
      expect(problem).not_to have_key(:errors)
    end

    # Requests the contract doesn't describe raise in the test integration,
    # so these failures are built directly.
    it "returns an about:blank problem for an undocumented content type" do
      failure = OpenapiFirst::Failure.new(:unsupported_media_type, message: "Content-Type text/plain is not defined.")

      expect(described_class.from_contract_failure(failure).to_h).to eq(
        type: "about:blank", title: "Unsupported Media Type", status: 415, detail: "Content-Type text/plain is not defined."
      )
    end

    it "returns an about:blank problem for an undocumented method" do
      failure = OpenapiFirst::Failure.new(:method_not_allowed)

      expect(described_class.from_contract_failure(failure).to_h).to include(
        type: "about:blank", title: "Method Not Allowed", status: 405
      )
    end
  end
end
