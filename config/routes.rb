Rails.application.routes.draw do
  resources :assets, only: %i(show create update destroy) do
    member do
      post :restore
    end
  end

  get "/media/:id/:filename" => "media#download", :constraints => { filename: /.*/ }

  get "/healthcheck" => Proc.new { [200, { "Content-type" => "text/plain" }, ["OK"]] }
end
