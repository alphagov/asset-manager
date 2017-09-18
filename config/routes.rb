Rails.application.routes.draw do
  resources :assets, only: %i(show create update destroy) do
    member do
      post :restore
    end
  end

  resources :whitehall_assets, only: %i(create)

  get "/media/:id/:filename" => "media#download", :constraints => { filename: /.*/ }

  get "/healthcheck" => Proc.new { [200, { "Content-type" => "text/plain" }, ["OK"]] }
end
