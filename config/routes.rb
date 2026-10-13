require "rack/session/cookie"
require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :books, only: %i[index show create destroy], param: :serial_number do
        resource :status, only: :update, controller: "book_statuses"
      end
      resources :readers, only: %i[index show create], param: :card_number
    end
  end

  # The API is sessionless, so the session middleware Sidekiq::Web needs is mounted for this endpoint only.
  # Like the rest of the app it is unauthenticated - see README.
  mount Rack::Builder.new {
    use Rack::Session::Cookie, secret: Rails.application.secret_key_base, same_site: true, max_age: 86_400
    run Sidekiq::Web
  }, at: "/sidekiq"

  get "up" => "rails/health#show", as: :rails_health_check
end
