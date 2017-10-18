Rails.application.routes.draw do
  resources :assets, only: %i(show create update destroy) do
    member do
      post :restore
    end
  end

  resources :whitehall_assets, only: %i(create)
  get '/whitehall_assets/*path' => 'whitehall_assets#show'

  get "/media/:id/:filename" => "media#download", :constraints => { filename: /.*/ }
  get "/government/uploads/*path" => "whitehall_media#download"

  get "/healthcheck" => Proc.new { [200, { "Content-type" => "text/plain" }, ["OK"]] }
end
