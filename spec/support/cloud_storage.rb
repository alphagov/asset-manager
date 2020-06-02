require "services"

RSpec.configure do |config|
  config.before do |example|
    unless example.metadata[:disable_cloud_storage_stub]
      cloud_storage = instance_double(S3Storage).as_null_object
      allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
    end
  end
end
