FactoryBot.define do
  factory :asset do
    file { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/asset.svg")) }
  end
  factory :virus_clean_asset, parent: :asset do
    after :create, &:virus_scanned_clean!
  end
  factory :clean_asset, parent: :virus_clean_asset do
    after :create, &:svg_scanned_clean!
  end
  factory :infected_asset, parent: :asset do
    after :create, &:scanned_infected!
  end
  factory :uploaded_asset, parent: :clean_asset do
    after :create, &:upload_success!
  end

  factory :svg_asset_safe do
    file { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/asset-safe.svg")) }
  end
  factory :svg_asset_unsafe_element do
    file { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/asset-unsafe-element.svg")) }
  end
  factory :svg_asset_unsafe_event_handler do
    file { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/asset-unsafe-event-handler.svg")) }
  end
  factory :svg_asset_unsafe_uri do
    file { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/asset-unsafe-uri.svg")) }
  end

  factory :deleted_asset, parent: :asset do
    deleted_at { Time.zone.now }
  end

  factory :whitehall_asset, parent: :asset, class: "WhitehallAsset" do
    sequence(:legacy_url_path) { |n| "/government/uploads/asset-#{n}.png" }

    trait :with_legacy_metadata do
      sequence(:legacy_etag) { |n| "legacy-etag-#{n}" }
      sequence(:legacy_last_modified) { |n| Time.zone.parse("2000-01-01") + n.days }
    end
  end

  factory :clean_whitehall_asset, parent: :whitehall_asset do
    after :create, &:virus_scanned_clean!
  end

  factory :uploaded_whitehall_asset, parent: :clean_whitehall_asset do
    after :create, &:upload_success!
  end

  factory :user do
    sequence(:name) { |n| "Winston #{n}" }
    permissions { %w[signin] }
  end
end
