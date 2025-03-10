ENV["RAILS_ENV"] = "test"
ENV["PACT_DO_NOT_TRACK"] = "true"
require "webmock"
require "pact/provider/rspec"
require "rails_helper"
require "factory_bot_rails"

WebMock.disable!

Pact.configure do |config|
  config.reports_dir = "spec/reports/pacts"
  config.include WebMock::API
  config.include WebMock::Matchers
  config.include FactoryBot::Syntax::Methods
end

Pact.service_provider "Asset Manager" do
  include ERB::Util

  honours_pact_with "GDS API Adapters" do
    if ENV["PACT_URI"]
      pact_uri(ENV["PACT_URI"])
    else
      base_url = ENV.fetch("PACT_BROKER_BASE_URL", "https://govuk-pact-broker-6991351eca05.herokuapp.com")
      url = "#{base_url}/pacts/provider/#{url_encode(name)}/consumer/#{url_encode(consumer_name)}"

      pact_uri "#{url}/versions/#{url_encode(ENV.fetch('PACT_CONSUMER_VERSION', 'branch-main'))}"
    end
  end
end

Pact.provider_states_for "GDS API Adapters" do
  set_up do
    WebMock.enable!
    WebMock.reset!
    DatabaseCleaner.clean_with :deletion
    GDS::SSO.test_user = create(:user)
    AssetManager.s3 = S3Configuration.build
    allow(AssetManager.s3).to receive(:fake?).and_return(false)
  end

  tear_down do
    WebMock.disable!
  end

  provider_state "an asset exists with identifier 4dca570c2975bc0d6d437491" do
    set_up do
      FactoryBot.create(:uploaded_asset, id: "4dca570c2975bc0d6d437491")
    end
  end

  provider_state "a soft deleted asset exists with identifier 4dca570c2975bc0d6d437491" do
    set_up do
      FactoryBot.create(:deleted_asset, id: "4dca570c2975bc0d6d437491")
    end
  end

  provider_state "an asset exists with id 4dca570c2975bc0d6d437491 and filename asset.png" do
    set_up do
      FactoryBot.create(:uploaded_asset, id: "4dca570c2975bc0d6d437491")
    end
  end

  provider_state "a whitehall asset exists with legacy url path /government/uploads/some-edition/hello.txt and id 4dca570c2975bc0d6d437491" do
    set_up do
      FactoryBot.create(:uploaded_whitehall_asset, legacy_url_path: "/government/uploads/some-edition/hello.txt", id: "4dca570c2975bc0d6d437491")
    end
  end

  provider_state "a soft deleted whitehall asset exists with legacy url path /government/uploads/some-edition/hello.txt and id 4dca570c2975bc0d6d437491" do
    set_up do
      FactoryBot.create(:uploaded_whitehall_asset, legacy_url_path: "/government/uploads/some-edition/hello.txt", id: "4dca570c2975bc0d6d437491", deleted_at: Time.zone.now)
    end
  end
end
