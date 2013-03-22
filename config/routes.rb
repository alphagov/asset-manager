AssetManager::Application.routes.draw do
  resources :assets, :only => [:show, :create]

  match "media/:id/:filename" => "media#download", :constraints => { :filename => /.*/ }

  get "/healthcheck" => Proc.new { [200, {"Content-type" => "text/plain"}, ["OK"]] }
end
