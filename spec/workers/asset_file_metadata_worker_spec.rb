require 'rails_helper'

RSpec.describe AssetFileMetadataWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:asset) { FactoryGirl.create(:asset) }

  it 'sets Asset#etag to Asset#etag_from_file in database' do
    asset.set(etag: nil)

    worker.perform(asset.id.to_s)

    expect(asset.reload.etag).to eq(asset.etag_from_file)
  end

  it 'sets Asset#last_modified to Asset#last_modified_from_file in database' do
    asset.set(last_modified: nil)

    worker.perform(asset.id.to_s)

    expect(asset.reload.last_modified).to be_within_a_millisecond_of(asset.last_modified_from_file)
  end

  it 'sets Asset#md5_hexdigest to Asset#md5_hexdigest_from_file in database' do
    asset.set(md5_hexdigest: nil)

    worker.perform(asset.id.to_s)

    expect(asset.reload.md5_hexdigest).to eq(asset.md5_hexdigest_from_file)
  end
end
