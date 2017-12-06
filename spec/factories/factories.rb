FactoryBot.define do
  factory :asset do
    file { Rack::Test::UploadedFile.new(Rails.root.join("spec", "fixtures", "files", "asset.png")) }
  end
  factory :clean_asset, parent: :asset do
    after :create, &:scanned_clean!
  end
  factory :infected_asset, parent: :asset do
    after :create, &:scanned_infected!
  end

  factory :access_limited_asset, parent: :clean_asset do
    access_limited true
    organisation_slug 'example-organisation'
  end

  factory :deleted_asset, parent: :asset do
    deleted_at { Time.now }
  end

  factory :whitehall_asset, parent: :asset, class: WhitehallAsset do
    sequence(:legacy_url_path) { |n| "/government/uploads/asset-#{n}.png" }

    trait :with_legacy_metadata do
      sequence(:legacy_etag) { |n| "legacy-etag-#{n}" }
      sequence(:legacy_last_modified) { |n| Time.parse('2000-01-01') + n.days }
    end
  end

  factory :clean_whitehall_asset, parent: :whitehall_asset do
    after :create, &:scanned_clean!
  end

  factory :user do
    sequence(:name) { |n| "Winston #{n}" }
    permissions { ["signin"] }
  end
end
