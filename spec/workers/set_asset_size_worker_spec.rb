require "rails_helper"

RSpec.describe SetAssetSizeWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:asset) { FactoryBot.create(:uploaded_asset_without_size) }

  it "sets the size of the asset" do
    expect(asset.size).to be_nil
    worker.perform(asset.id)
    expect(asset.reload.size).to eq(57705)
  end
end
