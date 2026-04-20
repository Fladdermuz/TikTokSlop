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
    resources :campaigns do
      member do
        post :transition
      end
    end
    resources :products, only: %i[index new create show edit update] do
      resource :knowledge, only: %i[show edit update], controller: "product_knowledges"
    end
    resource  :moderation_preview, only: %i[create]
    resource  :message_generation, only: %i[create]
    resources :invites, only: %i[index show] do
      member do
        post :retry_send
        post :generate_link
        post :reinvite
      end
    end
    resources :bulk_invites, only: %i[new create] do
      collection do
        get  :import
        post :import_csv
      end
    end
    resources :samples, only: %i[index show update] do
      member do
        post :record_spark_code
        get  :deeplink
      end
    end
    resource  :tiktok_connection, only: %i[show create destroy]
    resource  :open_collab_settings, only: %i[show update]
    resources :members,     only: %i[index new create destroy]
    resource  :roi, only: [:show], controller: "roi"
    resource  :finance, only: [:show], controller: "finance" do
      collection do
        get :payments
        get :statements
        get :transactions
      end
    end
  end

  namespace :tiktok do
    get  :callback, to: "oauth#callback"
    post :webhooks, to: "webhooks#receive"
  end

  namespace :admin do
    resource :dashboard, only: :show
    resources :shops
    resources :users
  end

  # Public pages (unauthenticated)
  get "privacy",            to: "pages#privacy"
  get "terms",              to: "pages#terms"
  get "incident-response",  to: "pages#incident_response"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
