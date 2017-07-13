AssetUploader.class_eval do
  def store_base_dir
    "#{Rails.root}/tmp/test_uploads"
  end
end

def clean_upload_directory!
  FileUtils.rm_rf(Dir["#{Rails.root}/tmp/test_uploads/[^.]*"])
end

RSpec.configuration.after(:suite) do
  clean_upload_directory!
end
