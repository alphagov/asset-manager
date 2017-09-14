FactoryGirl.define do
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

  factory :user do
    sequence(:name) { |n| "Winston #{n}" }
    permissions { ["signin"] }
  end
end
