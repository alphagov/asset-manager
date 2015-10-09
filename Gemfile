source 'https://rubygems.org'

gem 'rails', '3.2.22'
gem 'mongoid', '2.4.12'
gem 'bson_ext', '1.6.4'

gem 'unicorn', '4.5.0'

gem 'airbrake', '~> 4.0.0'

gem 'carrierwave', '0.6.1'
gem 'carrierwave-mongoid', '0.2.1', :require => 'carrierwave/mongoid'

gem 'state_machine', '~> 1.2.0'

gem 'delayed_job', '3.0.5'
gem 'delayed_job_mongoid', '1.1.0'

if ENV['BUNDLE_DEV']
  gem 'gds-sso', path: '../gds-sso'
else
  gem 'gds-sso', '9.3.0'
end

gem 'plek', '1.3.0'
gem 'logstasher', '0.4.8'
gem 'rack_strip_client_ip', '0.0.1'

group :assets do
  gem 'uglifier', '>= 1.0.3'
end

group :development, :test do
  gem 'rspec-rails', '~> 2.99.0'

  # NOTE: 1.5.0 has a bug with mongoid and truncation: https://github.com/DatabaseCleaner/database_cleaner/issues/299
  gem 'database_cleaner', '~> 1.4.0'

  gem 'simplecov-rcov', '0.2.3'
  gem 'ci_reporter_rspec', '~> 1.0.0'

  gem "factory_girl_rails", "~> 4.0"
end
