Rails.application.routes.draw do
  resources :assets, :only => [:show, :create, :update, :destroy]
  post "/assets/:id/restore", to: "assets#restore"

  get "/media/:id/:filename" => "media#download", :constraints => { :filename => /.*/ }

  get "/healthcheck" => Proc.new { [200, {"Content-type" => "text/plain"}, ["OK"]] }
end
