require "openapi_first/test"

# Contract testing (ADR 0005): every request and response in request specs is validated
# against docs/openapi.yaml, and a mismatch fails the spec. Coverage of the contract is
# reported at the end of the run.
OpenapiFirst::Test.setup do |test|
  test.coverage_reporter = OpenapiFirst::Test::Coverage::TerminalReporter
  # With OPENAPI_COVERAGE=strict (set in CI), the run fails unless every documented
  # request and response was exercised. Otherwise, e.g. when running a single spec
  # file, uncovered parts of the contract only warn.
  test.report_coverage = ENV["OPENAPI_COVERAGE"] == "strict" ? true : :warn
  # HEAD isn't described in the contract; the app answers it like the matching GET.
  test.ignore_request_error(&:head?)
  test.ignore_response_error { |_response, rack_request| rack_request.head? }
end

OpenapiFirst::Test.observe(Rails.application)
