require 'rails_helper'

RSpec.describe DeleteAssetFileFromNfsWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:asset) { FactoryBot.create(:asset, state: state) }
  let(:path) { asset.file.path }

  context 'when asset is not uploaded' do
    let(:state) { 'unscanned' }

    it 'does not set file attribute to blank' do
      worker.perform(asset.id.to_s)

      expect(asset.reload.file).to be_present
    end

    it 'does not remove the underlying file' do
      worker.perform(asset.id.to_s)

      expect(File).to exist(path)
    end
  end

  context 'when asset is uploaded' do
    let(:state) { 'uploaded' }

    it 'sets file attribute to blank' do
      worker.perform(asset.id.to_s)

      expect(asset.reload.file).to be_blank
    end

    it 'removes the underlying file' do
      worker.perform(asset.id.to_s)

      expect(File).not_to exist(path)
    end
  end
end
