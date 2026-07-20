Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }

  root "home#index"
  namespace :admin do
    root "dashboard#index"
  end

  namespace :manager do
    root "dashboard#index"
    resources :users, only: [:new, :create, :show, :edit, :update, :destroy]
  end

  namespace :agent do
    root "dashboard#index"
  end

  namespace :customer do
    root "dashboard#index"
    get "wiki", to: "wiki#index", as: :wiki
  end


  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest


  resources :tickets, only: [:index, :show, :new, :create] do
    collection do
      get :catalogue
    end
    member do
      patch :assign
      patch :self_assign
      patch :close
      patch :cancel
    end
    resources :ticket_messages, only: [:create]
    resource  :hiring_detail,      only: [:new, :create]
    resource  :termination_detail, only: [:new, :create]
  end

  get  "hiring_detail/new",      to: "hiring_details#new_pending",      as: :new_pending_hiring_detail
  post "hiring_detail",          to: "hiring_details#create_pending",   as: :pending_hiring_detail
  post "hiring_detail/skip",     to: "hiring_details#skip_pending",     as: :skip_pending_hiring_detail
  get  "termination_detail/new", to: "termination_details#new_pending", as: :new_pending_termination_detail
  post "termination_detail",     to: "termination_details#create_pending", as: :pending_termination_detail
  post "termination_detail/skip", to: "termination_details#skip_pending", as: :skip_pending_termination_detail

  resources :ticket_notifications, only: [:index] do
    member    { patch :mark_read }
    collection { patch :mark_all_read }
  end
  resources :users, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member { patch :deactivate }
  end
end
