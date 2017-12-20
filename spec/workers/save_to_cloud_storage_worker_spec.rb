require 'rails_helper'

RSpec.describe SaveToCloudStorageWorker, type: :worker do
  let(:worker) { described_class.new }

  describe "#perform" do
    let(:asset) { FactoryBot.create(:clean_asset) }
    let(:cloud_storage) { double(:cloud_storage) }

    before do
      allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
      allow(cloud_storage).to receive(:save)
    end

    it 'saves the asset to cloud storage' do
      expect(cloud_storage).to receive(:save).with(asset)

      worker.perform(asset)
    end

    it 'changes the state of the asset to uploaded' do
      worker.perform(asset)

      expect(asset.reload).to be_uploaded
    end

    context 'when CloudStorage::ObjectUploadFailedError is raised' do
      before do
        allow(cloud_storage).to receive(:save)
          .and_raise(CloudStorage::ObjectUploadFailedError)
      end

      it 'changes the state of the asset to not_uploaded' do
        worker.perform(asset) rescue nil

        expect(asset.reload).to be_not_uploaded
      end

      it 're-raises the original exception so job will be retried' do
        expect { worker.perform(asset) }
          .to raise_error(CloudStorage::ObjectUploadFailedError)
      end
    end

    context 'when asset is in not_uploaded state, i.e. previous upload failed' do
      let(:asset) { FactoryBot.create(:not_uploaded_asset) }

      it 'saves the asset to cloud storage' do
        expect(cloud_storage).to receive(:save).with(asset)

        worker.perform(asset)
      end

      it 'changes the state of the asset to uploaded' do
        worker.perform(asset)

        expect(asset.reload).to be_uploaded
      end
    end
  end
end
