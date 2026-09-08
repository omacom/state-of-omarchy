Rails.application.routes.draw do
  root "home#show"

  # Passwordless sign-in (Fizzy-style): email -> emailed link + code -> session.
  resource :session, only: [ :create, :destroy ] do
    scope module: :sessions do
      resource :magic_link, only: [ :show, :create, :destroy ]
    end
  end
  # Emailed link. GET renders a page that POSTs the token (so mail scanners
  # prefetching the URL can't burn the single-use token).
  get "session/magic_link/:token", to: "sessions/magic_links#verify", as: :verify_magic_link
  get "auth/error", to: "sessions/magic_links#error", as: :auth_error

  resource :waitlist_signup, only: :create

  # The survey itself: one page per section, autosaved, submitted once.
  resource :survey, only: [ :show, :update ] do
    post :submit
    get :done
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
