def clean_upload_directory!
  FileUtils.rm_rf(Dir["#{AssetManager.carrier_wave_store_base_dir}/[^.]*"])
end

RSpec.configuration.after(:suite) do
  clean_upload_directory!
end
