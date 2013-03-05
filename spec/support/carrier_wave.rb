CarrierWave::Uploader::Base.descendants.each do |klass|
  next if klass.anonymous?
  klass.class_eval do
    def cache_dir
      "#{Rails.root}/tmp/test_uploads/tmp"
    end

    def store_dir
      "#{Rails.root}/tmp/test_uploads/#{model.class.to_s.underscore}/#{model.id}"
    end
  end
end

def clean_upload_directory!
  FileUtils.rm_rf(Dir["#{Rails.root}/tmp/test_uploads/[^.]*"])
end

RSpec.configuration.after(:suite) do
  clean_upload_directory!
end

AssetUploader.enable_processing = false
