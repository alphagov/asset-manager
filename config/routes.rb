AssetManager::Application.routes.draw do
  scope :path => "#{ASSET_PREFIX}" do
    resources :assets, :only => [:show, :create]
    match "files/:id/:filename" => "files#download",
          :constraints => { :filename => /.*/ }
  end

  root :to => redirect("/#{ASSET_PREFIX}", :status => 302)
end
