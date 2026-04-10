Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "dashboard#show"

  resources :shops, only: %i[index new create] do
    member do
      post :switch
    end
  end

  # Everything below operates under Current.shop set by the ShopContext concern.
  namespace :shop do
    resource :dashboard, only: :show
    resources :creators, only: %i[index show] do
      collection do
        post :export
      end
    end
    resources :campaigns
    resources :invites,     only: %i[index show]
    resources :samples,     only: %i[index show]
    resource  :tiktok_connection, only: %i[show create destroy]
    resources :members,     only: %i[index new create destroy]
  end

  namespace :tiktok do
    get :callback, to: "oauth#callback"
  end

  namespace :admin do
    resource :dashboard, only: :show
    resources :shops
    resources :users
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
