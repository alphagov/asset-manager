AssetManager::Application.routes.draw do
  resources :assets, :only => [:show, :create]
end
