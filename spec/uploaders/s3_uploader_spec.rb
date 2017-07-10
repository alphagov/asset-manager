require "rails_helper"

RSpec.describe S3Uploader, type: :uploader do
  let(:asset) { Asset.new(file: load_fixture_file("asset.png")) }
  subject { described_class.new(asset) }

  let(:object) { double(:object, upload_file: nil) }
  let(:bucket) { double(:bucket, object: object) }
  let(:s3_resource) { double(bucket: bucket) }

  before do
    allow(subject).to receive(:upload).and_call_original
    allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
  end

  describe '#upload' do
    it 'creates an object with the same id as the asset' do
      expect(bucket).to receive(:object).with(asset.id.to_s)

      subject.upload
    end

    it 'uploads the object to S3' do
      expect(object).to receive(:upload_file).with(asset.file.path)

      subject.upload
    end
  end
end
