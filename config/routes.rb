Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # The API contract is docs/openapi.yaml (ADR 0005).
  resources :books, only: %i[index show create destroy], param: :serial_number
end
