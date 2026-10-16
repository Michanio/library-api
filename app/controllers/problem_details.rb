# The body of an RFC 9457 problem details response (application/problem+json).
# See ADR 0005 for the problem types and when each status is used.
class ProblemDetails < Data.define(:status, :type, :title, :detail, :errors)
  INVALID_REQUEST = "urn:library-api:problem:invalid-request"

  # Statuses for openapi_first failures that aren't about the request's content.
  # Every other failure means the request doesn't match the contract (400).
  CONTRACT_FAILURE_STATUSES = {
    not_found: 404,
    method_not_allowed: 405,
    unsupported_media_type: 415
  }.freeze

  def self.about_blank(status, detail: nil)
    new(status:, type: "about:blank", title: Rack::Utils::HTTP_STATUS_CODES.fetch(status), detail:, errors: nil)
  end

  # Builds a problem from an OpenapiFirst::Failure.
  def self.from_contract_failure(failure)
    status = CONTRACT_FAILURE_STATUSES[failure.type]
    return about_blank(status, detail: failure.message) if status

    errors = field_errors(failure.errors) if failure.type == :invalid_body
    new(status: 400, type: INVALID_REQUEST, title: "Invalid request", detail: failure.message, errors: errors.presence)
  end

  # Maps schema validation errors to `{ pointer:, detail: }` entries that point at
  # request body fields. A missing-properties error points at the object that is
  # missing them, so it's split into one entry per missing field.
  def self.field_errors(schema_errors)
    Array(schema_errors).flat_map do |error|
      case error.type
      when "required"
        error.details.fetch("missing_keys").map { |key| { pointer: "#{error.data_pointer}/#{key}", detail: "is required" } }
      when "schema" # a `false` schema, i.e. a field not allowed by `additionalProperties: false`
        { pointer: error.data_pointer, detail: "is not allowed" }
      else
        { pointer: error.data_pointer, detail: error.message }
      end
    end
  end

  def to_h
    { type:, title:, status:, detail:, errors: }.compact
  end
end
