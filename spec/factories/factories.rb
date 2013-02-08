FactoryGirl.define do
  factory :asset do
    file Rack::Test::UploadedFile.new(Rails.root.join("spec", "fixtures", "files", "asset.png"))
  end

  factory :user do
    sequence(:name) { |n| "Winston #{n}"}
    permissions { ["signin"] }
  end
end
