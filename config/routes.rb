AssetManager::Application.routes.draw do
  resources :assets, :only => [:show, :create]

  match "media/:id/:filename" => "media#download", :constraints => { :filename => /.*/ }
end
