AssetManager::Application.routes.draw do
  resources :assets, :only => [:show, :create]
  match "files/:id/:filename" => "files#download", :constraints => { :filename => /.*/ }
end
