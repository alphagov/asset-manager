require 'rails_helper'

RSpec.describe DeletedAssetSaveToCloudStorageWorker, type: :worker do
  let(:worker) { described_class.new(cloud_storage: s3_storage) }
  let(:s3_storage) { instance_double(S3Storage) }

  describe "#perform" do
    let(:asset) { FactoryGirl.create(:clean_asset) }

    before do
      asset.destroy
    end

    it 'saves the deleted asset to S3 storage' do
      expect(s3_storage).to receive(:save).with(asset)

      worker.perform(asset)
    end
  end
end
