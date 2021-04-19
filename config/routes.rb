Rails.application.routes.draw do
  resources :assets, only: %i[show create update destroy] do
    member do
      post :restore
    end
  end

  resources :whitehall_assets, only: %i[create]
  get "/whitehall_assets/*path" => "whitehall_assets#show"

  get "/media/:id/:filename" => "media#download", :constraints => { filename: /.*/ }, as: :download_media
  get "/government/uploads/*path" => "whitehall_media#download"

  if AssetManager.s3.fake?
    mount Rack::File.new(AssetManager.fake_s3.root), at: AssetManager.fake_s3.path_prefix, as: "fake_s3"
  end

  get "/healthcheck", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::ActiveRecord,
    GovukHealthcheck::SidekiqRedis,
  )
end
