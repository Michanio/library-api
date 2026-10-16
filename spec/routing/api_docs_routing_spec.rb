require "rails_helper"

# The Swagger UI pages are development tooling and aren't routed in other environments.
RSpec.describe "API docs routes", type: :routing do
  it "doesn't route the docs outside development" do
    expect(get: "/docs").not_to be_routable
    expect(get: "/docs/openapi.yaml").not_to be_routable
  end
end
