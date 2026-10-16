class ApplicationController < ActionController::API
  before_action :validate_request_against_contract

  private
    # Rejects requests that don't match docs/openapi.yaml before they reach an action (ADR 0005).
    def validate_request_against_contract
      validated = OpenapiFirst[:default].validate_request(request)
      render_problem ProblemDetails.from_contract_failure(validated.error) if validated.invalid?
    end

    def render_problem(problem)
      render json: problem.to_h, status: problem.status, content_type: "application/problem+json"
    end
end
