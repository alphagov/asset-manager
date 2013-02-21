AssetManager::Application.routes.draw do
  resources :assets, :only => [:show, :create]

  match "media/:id/:filename" => "media#download", :constraints => { :filename => /.*/ }
  match "media/:id" => "media#redirect"
end
