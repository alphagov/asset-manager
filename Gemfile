source 'https://rubygems.org'

gem 'rails', '4.2.4'
gem 'mongoid', '~> 4.0'

gem 'unicorn', '4.5.0'

gem 'airbrake', '~> 4.0.0'

gem 'carrierwave', '~> 0.10.0'
gem 'carrierwave-mongoid', '~> 0.8.1', :require => 'carrierwave/mongoid'

gem 'state_machines-mongoid', '~> 0.1.1'

gem 'delayed_job', '~> 4.1.1'
gem 'delayed_job_mongoid', '~> 2.2.0'

if ENV['BUNDLE_DEV']
  gem 'gds-sso', path: '../gds-sso'
else
  gem 'gds-sso', '9.3.0'
end

gem 'plek', '1.3.0'
gem 'logstasher', '0.4.8'
gem 'rack_strip_client_ip', '0.0.1'

gem 'uglifier', '>= 1.3.0'

# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

group :development, :test do
  gem 'rspec-rails', '~> 2.99.0'

  # NOTE: 1.5.0 has a bug with mongoid and truncation: https://github.com/DatabaseCleaner/database_cleaner/issues/299
  gem 'database_cleaner', '~> 1.4.0'

  gem 'simplecov-rcov', '0.2.3'
  gem 'ci_reporter_rspec', '~> 1.0.0'

  gem "factory_girl_rails", "~> 4.0"
end
