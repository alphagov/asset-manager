require 'rails_helper'

RSpec.describe SaveToCloudStorageWorker, type: :worker do
  let(:worker) { described_class.new }

  describe "#perform" do
    let(:asset) { FactoryBot.create(:clean_asset) }
    let(:cloud_storage) { double(:cloud_storage) }

    before do
      allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
    end

    it 'saves the asset to cloud storage' do
      expect(cloud_storage).to receive(:save).with(asset)

      worker.perform(asset)
    end
  end
end
