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

  namespace :settings do
  resource :organization,
           only: %i[edit update]
  end

  resources :branches, except: %i[show destroy] do
    patch :select, on: :member
  end

  resources :team_members,
          except: %i[show destroy]

  namespace :account do
     resource :password,
           only: %i[edit update]
  end

  resources :customers, except: :destroy do
      patch :toggle_status, on: :member
    end

    resources :suppliers, except: :destroy do
      patch :toggle_status, on: :member
    end

  resources :product_categories,
              except: %i[show destroy] do
      patch :toggle_status, on: :member
    end

    resources :unit_of_measures,
              except: %i[show destroy] do
      patch :toggle_status, on: :member
    end

    resources :tax_rates,
              except: %i[show destroy] do
      patch :toggle_status, on: :member
    end

    resources :items, except: :destroy do
      patch :toggle_status, on: :member
    end

  get "up" => "rails/health#show",
      as: :rails_health_check
end
