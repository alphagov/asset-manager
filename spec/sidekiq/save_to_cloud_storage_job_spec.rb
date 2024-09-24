require "rails_helper"

RSpec.describe SaveToCloudStorageJob, type: :worker do
  let(:worker) { described_class.new }

  describe "#perform" do
    let(:asset) { FactoryBot.create(:clean_asset) }
    let(:cloud_storage) { instance_double(S3Storage) }

    before do
      allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
      allow(cloud_storage).to receive(:upload)
    end

    it "saves the asset to cloud storage" do
      expect(cloud_storage).to receive(:upload).with(asset)

      worker.perform(asset)
    end

    it "changes the state of the asset to uploaded" do
      worker.perform(asset)

      expect(asset.reload).to be_uploaded
    end

    context "when asset is already uploaded" do
      let(:asset) { FactoryBot.create(:uploaded_asset) }

      it "does not save the asset to cloud storage" do
        expect(cloud_storage).not_to receive(:upload).with(asset)

        worker.perform(asset)
      end

      it "does not change the state of the asset" do
        worker.perform(asset)

        expect(asset.reload).to be_uploaded
      end
    end

    context "when S3Storage::ObjectUploadFailedError is raised" do
      before do
        allow(cloud_storage).to receive(:upload)
          .and_raise(S3Storage::ObjectUploadFailedError)
      end

      it "leaves the state of the asset set to clean" do
        begin
          worker.perform(asset)
        rescue StandardError
          nil
        end

        expect(asset.reload).to be_clean
      end
    end
  end
end
