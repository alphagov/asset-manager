require 'rails_helper'
require 's3_storage'

RSpec.describe S3Storage do
  subject { described_class.new(bucket_name) }

  let(:bucket_name) { 'bucket-name' }
  let(:s3_object) { instance_double(Aws::S3::Object) }
  let(:asset) { FactoryGirl.build(:asset) }
  let(:s3_object_params) { { bucket_name: bucket_name, key: asset.id.to_s } }

  describe '#save' do
    before do
      allow(Aws::S3::Object).to receive(:new).with(s3_object_params).and_return(s3_object)
    end

    it 'uploads file to S3 bucket' do
      expect(s3_object).to receive(:upload_file).with(asset.file.path)

      subject.save(asset)
    end
  end
end
