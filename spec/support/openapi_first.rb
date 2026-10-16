require "openapi_first/test"

# Contract testing (ADR 0005): every request and response in request specs is validated
# against docs/openapi.yaml, and a mismatch fails the spec. Coverage of the contract is
# reported at the end of the run.
OpenapiFirst::Test.setup do |test|
  test.coverage_reporter = OpenapiFirst::Test::Coverage::TerminalReporter
  # Most endpoints don't exist yet, so uncovered parts of the contract only warn for now.
  test.report_coverage = :warn
end

OpenapiFirst::Test.observe(Rails.application)
