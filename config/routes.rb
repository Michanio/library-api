Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Interactive API docs (Swagger UI) for the contract, in development only.
  if Rails.env.development?
    get "docs" => "api_docs#show", as: :api_docs
    get "docs/openapi.yaml" => "api_docs#contract", as: :api_docs_contract
  end

  # The API contract is docs/openapi.yaml (ADR 0005).
  resources :books, only: %i[index show create destroy], param: :serial_number do
    member do
      post :borrow, to: "lending#borrow"
      post :return, to: "lending#return_book"
    end
  end
end
