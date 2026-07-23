# routes.rb
Rails.application.routes.draw do
  root "about#index"

  get "about", to: "about#index"

  # Authentication
  get "sign-up", to: "registrations#new", as: :sign_up
  post "sign-up", to: "registrations#create"

  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"

  delete "logout", to: "sessions#destroy", as: :logout

  # Organization onboarding
  namespace :onboarding do
    resource :organization, only: %i[new create]
  end

  # Main organization dashboard
  resource :dashboard, only: :show

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end