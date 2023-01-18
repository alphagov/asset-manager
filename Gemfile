source "https://rubygems.org"

gem "rails", "7.0.4.1"

gem "addressable"
gem "aws-sdk-core"
gem "aws-sdk-s3"
gem "bootsnap", require: false
gem "carrierwave"
gem "carrierwave-mongoid", require: "carrierwave/mongoid"
gem "gds-sso"
gem "govuk_app_config"
gem "govuk_sidekiq"
gem "jwt"
gem "mail", "~> 2.7.1"  # TODO: remove once https://github.com/mikel/mail/issues/1489 is fixed.
gem "mongo", "~> 2.16.3"
gem "mongoid"
gem "nokogiri"
gem "plek"
gem "rack_strip_client_ip"
gem "rails-controller-testing"
gem "sentry-sidekiq"
gem "sprockets-rails"
gem "state_machines-mongoid"

group :development, :test do
  gem "brakeman"
  gem "byebug"
  gem "climate_control"
  gem "database_cleaner"
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
