require "healthcheck/cloud_storage"

Rails.application.routes.draw do
  get "/healthcheck/live", to: proc { [200, {}, %w[OK]] }
  get "/healthcheck/ready", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::Mongoid,
    GovukHealthcheck::SidekiqRedis,
    Healthcheck::CloudStorage,
  )

  get "/favicon.ico" => redirect("https://www.gov.uk/favicon.ico")

  resources :assets, only: %i[show create update destroy] do
    member do
      post :restore
    end
  end

  get "/media/:id/:filename" => "media#download", :constraints => { filename: /.*/ }, as: :download_media
  get "/government/uploads/*path" => "whitehall_media#download"

  if AssetManager.s3.fake?
    mount Rack::Files.new(AssetManager.fake_s3.root), at: AssetManager.fake_s3.path_prefix, as: "fake_s3"
  end

  require "sidekiq_unique_jobs/web"
  mount Sidekiq::Web, at: "/sidekiq"
end
