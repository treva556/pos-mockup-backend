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

  resources :customers do
        member do
        patch :toggle_status
        end

     resource :account,
                only: :show,
                controller: "customer_accounts"
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

  resources :money_accounts, except: :destroy do
      patch :toggle_status, on: :member
  end

  resources :payment_methods, except: :destroy do
      patch :toggle_status, on: :member
  end

  resources :branch_payment_settings,
                only: :index do
        patch :update_defaults,
              on: :collection
  end

  namespace :pos do
    resource :sale,
            only: %i[new create]

    resource :cart,
            only: %i[update destroy]

    resources :cart_items,
              only: %i[create update destroy],
              param: :item_id


    resource :checkout,
         only: :show

    resources :checkout_payments,
              only: %i[create update destroy],
              param: :entry_id
   end

    resources :sales,
              only: %i[index show] do
      member do
        get :receipt
      end

      resources :payments,
                only: %i[new create],
                controller: "sale_payments"
    end

    resources :inventory_adjustments,
          only: %i[new create]

    resources :money_transfers,
          only: %i[index show new create]

    resources :stock_transfers,
          only: %i[index show new create]

  resources :stock_levels, only: :index do
    patch :update_reorder_level,
          on: :collection
  end

  resources :stock_movements,
          only: %i[index show]

  get "up" => "rails/health#show",
      as: :rails_health_check
end
