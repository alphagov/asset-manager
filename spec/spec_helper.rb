require 'simplecov'
require 'simplecov-rcov'
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start 'rails'

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

AssetUploader.enable_processing = false

RSpec.configure do |config|
  config.mock_with :mocha

  config.after(:all) do
    clean_upload_directory!
  end

  config.infer_base_class_for_anonymous_controllers = false

  config.order = "random"
end

CarrierWave::Uploader::Base.descendants.each do |klass|
  next if klass.anonymous?
  klass.class_eval do
    def cache_dir
      "#{Rails.root}/spec/support/uploads/tmp"
    end

    def store_dir
      "#{Rails.root}/spec/support/uploads/#{model.class.to_s.underscore}/#{model.id}"
    end
  end
end

def clean_upload_directory!
  FileUtils.rm_rf(Dir["#{Rails.root}/spec/support/uploads/[^.]*"])
end
