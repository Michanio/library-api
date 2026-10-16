# Loads the API contract once at boot. ApplicationController validates every request
# against it, and request specs validate responses against it (ADR 0005).
# In development, restart the server after changing docs/openapi.yaml.
OpenapiFirst.configure do |config|
  # OpenAPI patterns are ECMA-262 regular expressions. In Ruby's dialect `$` would
  # also match before a trailing newline, so "123456\n" would pass `^\d{6}$`.
  config.regexp_resolver = "ecma"
end

OpenapiFirst.register(Rails.root.join("docs/openapi.yaml").to_s)
