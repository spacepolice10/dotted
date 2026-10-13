# frozen_string_literal: true

Rails.application.routes.draw do
  # --- System ---
  get 'up', to: 'rails/health#show', as: :rails_health_check
  get 'manifest', to: 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker', to: 'rails/pwa#service_worker', as: :pwa_service_worker

  root 'bullets#index'

  # --- Authentication ---
  resource :authentication, only: %i[new create destroy], controller: 'authentication' do
    scope module: :authentications do
      resource :confirmation, only: %i[new create]
    end
  end

  get 'features', to: 'landings#features', as: :features
  get 'terminal', to: 'landings#terminal', as: :terminal
  get 'agents', to: redirect('/terminal')
  get 'support', to: 'landings#support', as: :support
  get 'faqs', to: 'landings#faqs', as: :faqs
  get 'landing', to: 'landings#landing', as: :landing
  get 'once', to: 'landings#once', as: :once

  # --- Bullets ---
  scope 'bullets', module: :bullets do
    resource :postpone, only: %i[new create]
    resource :collect, only: %i[new create]
    resource :completion, only: %i[create destroy]
    resource :publish, only: %i[create destroy]
  end

  resources :bullets, except: %i[new edit] do
    collection do
      get :export, to: 'bullets/exports#show'
    end
  end

  # --- Collections ---
  resources :collections

  # --- Search & navigation ---
  get 'search/results', to: 'searches#results', as: :search_results

  resource :search, only: :show, controller: 'searches' do
    scope module: :searches do
      resource :selection, only: :create
      resource :appearance, only: :update
      post 'appearance', to: 'appearances#update'
    end
  end

  resource :user, only: :show

  resources :access_codes, only: %i[index new create destroy]
  resources :webhooks, only: %i[index new create destroy]
  post 'webhooks/:code', to: 'webhook_intakes#create', as: :webhook_intake, constraints: { code: /wh_[A-Za-z0-9]+/ }

  resources :completed, only: %i[index]

  # --- Attachments ---
  resources :attachments, only: %i[index show], param: :signed_id

  # --- Publishing ---
  resources :published, only: %i[index show], param: :code
end
