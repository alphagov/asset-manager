require "rails_helper"
require "pact/v2"
require "pact/v2/rspec"
require "webrick"

# The Pact v2 verifier serves the provider app with WEBrick, and its Rust core
# sends empty-bodied requests (.e.g. POST /assets/:id/restore) without a
# Content-Length header. WEBrick rejects those with a 411 LengthRequired
# response, even though RFC 7230 section 3.3.3 permits them. Treat POST/PUT
# requests that carry neither Content-Length nor Transfer-Encoding as having
# no body. See https://github.com/ruby/webrick/issues/30
PACT_WEBRICK_EMPTY_BODY_PATCH = Module.new do
  def read_body(socket, block)
    if self["content-length"].nil? && self["transfer-encoding"].nil? &&
        WEBrick::HTTPRequest::BODY_CONTAINABLE_METHODS.include?(@request_method)
      return @body
    end

    super
  end
end
WEBrick::HTTPRequest.prepend(PACT_WEBRICK_EMPTY_BODY_PATCH)

# The recorded pacts expect URLs like http://example.org/assets/<id> because
# the previous (Rack::Test based) verifier used example.org as its default
# host. Rewrite the request host so Rails URL helpers generate matching URLs.
class PactExampleOrgHost
  def initialize(app)
    @app = app
  end

  def call(env)
    env["HTTP_HOST"] = "example.org"
    env["SERVER_NAME"] = "example.org"
    env["SERVER_PORT"] = "80"
    env.delete("HTTP_X_FORWARDED_HOST")
    env.delete("HTTP_X_FORWARDED_PORT")
    @app.call(env)
  end
end

RSpec.describe "Verify pacts from GDS API Adapters", :pact_v2 do # rubocop:disable RSpec/EmptyExampleGroup
  Pact::V2.configure do |config|
    config.before_provider_state_setup do
      DatabaseCleaner.clean_with :deletion
      GDS::SSO.test_user = FactoryBot.create(:user, permissions: %w[signin])
      AssetManager.s3 = S3Configuration.build({ "AWS_S3_BUCKET_NAME" => "govuk-asset-manager-pact-verification" })
    end
  end

  http_pact_provider "Asset Manager", opts: {
    app: PactExampleOrgHost.new(Rails.application),
    http_port: 9292,
    pact_uri: ENV["PACT_URI"],
    broker_url: ENV.fetch("PACT_BROKER_BASE_URL", "https://govuk-pact-broker-6991351eca05.herokuapp.com"),
    consumer_name: "GDS API Adapters",
    consumer_version_selectors: [
      { branch: ENV.fetch("PACT_CONSUMER_VERSION", "branch-main").delete_prefix("branch-") },
    ],
    log_level: :info,
    fail_if_no_pacts_found: true,
  }

  provider_state "an asset exists with identifier 4dca570c2975bc0d6d437491" do
    set_up do
      FactoryBot.create(:uploaded_asset, id: "4dca570c2975bc0d6d437491", user: GDS::SSO.test_user)
    end
  end

  provider_state "a soft deleted asset exists with identifier 4dca570c2975bc0d6d437491" do
    set_up do
      FactoryBot.create(:deleted_asset, id: "4dca570c2975bc0d6d437491", user: GDS::SSO.test_user)
    end
  end

  provider_state "an asset exists with id 4dca570c2975bc0d6d437491 and filename asset.png" do
    set_up do
      FactoryBot.create(:uploaded_asset, id: "4dca570c2975bc0d6d437491", user: GDS::SSO.test_user)
    end
  end

  provider_state "a whitehall asset exists with legacy url path /government/uploads/some-edition/hello.txt and id 4dca570c2975bc0d6d437491" do
    set_up do
      FactoryBot.create(:uploaded_whitehall_asset, legacy_url_path: "/government/uploads/some-edition/hello.txt", id: "4dca570c2975bc0d6d437491", user: GDS::SSO.test_user)
    end
  end

  provider_state "a soft deleted whitehall asset exists with legacy url path /government/uploads/some-edition/hello.txt and id 4dca570c2975bc0d6d437491" do
    set_up do
      FactoryBot.create(:uploaded_whitehall_asset, legacy_url_path: "/government/uploads/some-edition/hello.txt", id: "4dca570c2975bc0d6d437491", deleted_at: Time.zone.now, user: GDS::SSO.test_user)
    end
  end
end
