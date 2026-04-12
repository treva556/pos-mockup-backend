Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # GET /about
  get "about", to: "about#index"

    get "/", to: "about#index"


  # get "up" => "rails/health#show", as: :rails_health_check


end
