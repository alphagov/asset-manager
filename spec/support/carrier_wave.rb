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

RSpec.configuration.after(:all) do
  clean_upload_directory!
end

AssetUploader.enable_processing = false
