if Rails.env.test?
  directory = "#{Rails.root}/tmp/test_uploads"
else
  directory = "#{ENV['GOVUK_APP_ROOT'] || Rails.root}/uploads"
end

AssetManager.carrier_wave_store_base_dir = directory
