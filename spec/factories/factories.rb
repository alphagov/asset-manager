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
  factory :uploaded_asset, parent: :clean_asset do
    after :create, &:upload_success!
  end

  factory :deleted_asset, parent: :asset do
    deleted_at { Time.now }
  end

  factory :uploaded_asset_without_size, parent: :uploaded_asset do
    after(:create) do |asset, _|
      asset.send(:size=, nil)
      asset.save
    end
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

  factory :uploaded_whitehall_asset, parent: :clean_whitehall_asset do
    after :create, &:upload_success!
  end

  factory :user do
    sequence(:name) { |n| "Winston #{n}" }
    permissions { %w(signin) }
  end
end
