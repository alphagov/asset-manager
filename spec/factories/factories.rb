FactoryGirl.define do
  factory :asset do
    file Rack::Test::UploadedFile.new(Rails.root.join("spec", "fixtures", "files", "asset.png"))
  end
end
