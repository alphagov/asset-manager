require 'rails_helper'

RSpec.describe AssetUploadStateWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:asset) { FactoryBot.create(:clean_asset) }
  let(:cloud_storage) { instance_double(S3Storage) }

  before do
    allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
    allow(cloud_storage).to receive(:exists?).with(asset).and_return(asset_exists)
  end

  context 'when file has been uploaded to cloud storage' do
    let(:asset_exists) { true }

    it 'sets state to uploaded' do
      worker.perform(asset.id.to_s)

      expect(asset.reload).to be_uploaded
    end

    context 'even when asset is marked as deleted' do
      before do
        asset.destroy
      end

      it 'still sets state to uploaded' do
        worker.perform(asset.id.to_s)

        expect(asset.reload).to be_uploaded
      end
    end
  end

  context 'when file has not been uploaded to cloud storage' do
    let(:asset_exists) { false }

    it 'leaves state set to clean' do
      worker.perform(asset.id.to_s)

      expect(asset.reload).to be_clean
    end
  end
end
