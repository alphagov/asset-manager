source "https://rubygems.org"

gem "rails", "8.1.2"

gem "addressable"
gem "aws-sdk-core"
gem "aws-sdk-s3"
gem "bootsnap", require: false
gem "carrierwave", "< 3" # pin at v2 to avoid breaking changes
gem "carrierwave-mongoid", require: "carrierwave/mongoid"
gem "csv"
gem "gds-sso"
gem "govuk_app_config"
gem "govuk_sidekiq"
gem "jwt"
gem "mongo", "~> 2.23.0"
gem "mongoid"
gem "nokogiri"
gem "observer"
gem "plek"
gem "rack_strip_client_ip"
gem "rails-controller-testing"
gem "sentry-sidekiq"
gem "sidekiq-unique-jobs", "< 8.0.8"
gem "sprockets-rails"
gem "state_machines-mongoid"

group :development, :test do
  gem "brakeman"
  gem "byebug"
  gem "climate_control"
  gem "database_cleaner-mongoid"
  gem "factory_bot_rails"
  gem "pact", require: false
  gem "pact_broker-client", require: false
  gem "rspec-rails"
  gem "rubocop-govuk"
  gem "simplecov"
  gem "webmock", require: false
end

group :development do
  gem "listen"
end

group :test do
  gem "rspec-sidekiq"
end
