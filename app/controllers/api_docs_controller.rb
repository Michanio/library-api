# Interactive API documentation (Swagger UI) for docs/openapi.yaml, routed in
# development only. Inherits from ActionController::Base rather than
# ApplicationController, because these pages aren't part of the API contract and
# would be rejected by its request validation.
class ApiDocsController < ActionController::Base
  def show
  end

  def contract
    send_file Rails.root.join("docs/openapi.yaml"), type: "application/yaml", disposition: "inline"
  end
end
