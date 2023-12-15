require "healthcheck/cloud_storage"

Rails.application.routes.draw do
  get "/healthcheck/live", to: proc { [200, {}, %w[OK]] }
  get "/healthcheck/ready", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::Mongoid,
    GovukHealthcheck::SidekiqRedis,
    Healthcheck::CloudStorage,
  )

  resources :assets, only: %i[show create update destroy] do
    member do
      post :restore
    end
  end

  get "/media/:id/:filename" => "media#download", :constraints => { filename: /.*/ }, as: :download_media
  get "/government/uploads/*path" => "whitehall_media#download"

  if AssetManager.s3.fake?
    mount Rack::File.new(AssetManager.fake_s3.root), at: AssetManager.fake_s3.path_prefix, as: "fake_s3"
  end
end
