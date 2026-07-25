# routes.rb
Rails.application.routes.draw do
  root "about#index"

  get "about", to: "about#index"

  get "sign-up", to: "registrations#new", as: :sign_up
  post "sign-up", to: "registrations#create"

  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"

  delete "logout", to: "sessions#destroy", as: :logout

  namespace :onboarding do
    resource :organization, only: %i[new create]
  end

  resource :dashboard, only: :show

  resources :branches, except: %i[show destroy] do
    patch :select, on: :member
  end

  get "up" => "rails/health#show",
      as: :rails_health_check
end