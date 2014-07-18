source 'https://BnrJb6FZyzspBboNJzYZ@gem.fury.io/govuk/'
source 'https://rubygems.org'

gem 'rails', '3.2.17'
gem 'mongoid', '2.4.12'
gem 'bson_ext', '1.6.4'

gem 'unicorn', '4.5.0'

gem 'exception_notification', '2.6.1'
gem 'aws-ses', '0.4.4', :require => 'aws/ses'

gem 'carrierwave', '0.6.1'
gem 'carrierwave-mongoid', '0.2.1', :require => 'carrierwave/mongoid'

gem 'state_machine', '1.1.2'

gem 'delayed_job', '3.0.5'
gem 'delayed_job_mongoid', '1.1.0'

if ENV['BUNDLE_DEV']
  gem 'gds-sso', path: '../gds-sso'
else
  gem 'gds-sso', '9.3.0'
end

gem 'plek', '1.3.0'
gem 'logstasher', '0.4.8'

group :assets do
  gem 'uglifier', '>= 1.0.3'
end

group :development, :test do
  gem 'rspec-rails', '2.12.2'
  gem 'database_cleaner', '0.9.1'

  gem 'simplecov-rcov', '0.2.3'
  gem 'ci_reporter', '1.8.4'

  gem "factory_girl_rails", "~> 4.0"
end
