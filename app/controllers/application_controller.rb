class ApplicationController < ActionController::API
  # HEAD isn't described in the contract, but every GET resource must answer it
  # (Rails routes it to the GET action and drops the body).
  before_action :validate_request_against_contract, unless: -> { request.head? }

  rescue_from Catalog::BookNotFound do |error|
    render_problem ProblemDetails.about_blank(404, detail: "#{error.message}.")
  end

  rescue_from Catalog::BookInvalid do |error|
    render_problem ProblemDetails.validation_failed("The book could not be saved.", error.errors)
  end

  private
    attr_reader :contract_request

    # Rejects requests that don't match docs/openapi.yaml before they reach an action (ADR 0005).
    def validate_request_against_contract
      @contract_request = OpenapiFirst[:default].validate_request(request)
      render_problem ProblemDetails.from_contract_failure(contract_request.error) if contract_request.invalid?
    end

    # The JSON request body, parsed and validated against the contract (string keys).
    def request_body
      contract_request.parsed_body
    end

    def render_problem(problem)
      render json: problem.to_h, status: problem.status, content_type: "application/problem+json"
    end
end
