require 'rails_helper'

RSpec.describe S3Storage::Fake do
  subject(:storage) { described_class.new(root_path) }

  let(:asset) { FactoryGirl.create(:asset) }
  let(:source_root) { AssetManager.carrier_wave_store_base_dir }
  let(:root_directory) { Dir.mktmpdir }
  let(:root_path) { Pathname.new(root_directory.to_s) }
  let(:relative_path_to_asset) { storage.relative_path_for(asset) }

  after do
    FileUtils.remove_entry(root_directory)
  end

  it 'implements all public methods defined on S3Storage' do
    methods = S3Storage.public_instance_methods(false)
    expect(described_class.public_instance_methods(false)).to include(*methods)
  end

  describe '#save' do
    let(:asset_path) { root_path.join(relative_path_to_asset) }

    it 'writes file to fake S3 storage directory' do
      storage.save(asset)

      expect(File.exist?(asset_path)).to be_truthy
    end
  end

  describe '#presigned_url_for' do
    before do
      storage.save(asset)
    end

    it 'returns URL with path starting with fake S3 path prefix' do
      url = storage.presigned_url_for(asset)
      path = URI(url).path

      expect(path).to start_with(AssetManager.fake_s3_path_prefix)
    end

    it 'returns URL with path ending with relative path to asset' do
      url = storage.presigned_url_for(asset)
      path = URI(url).path

      expect(path).to end_with(relative_path_to_asset.to_s)
    end

    it 'returns URL with host set to AssetManager.app_host' do
      url = storage.presigned_url_for(asset)
      scheme, domain, port = URI(url).select(:scheme, :host, :port)
      host = "#{scheme}://#{domain}:#{port}"

      expect(host).to eq(AssetManager.app_host)
    end
  end

  describe '#exists?' do
    let(:asset_path) { root_path.join(relative_path_to_asset) }

    context 'when file is not saved in storage' do
      it 'returns falsey' do
        expect(storage.exists?(asset)).to be_falsey
      end
    end

    context 'when file is saved in storage' do
      before do
        storage.save(asset)
      end

      it 'returns truthy' do
        expect(storage.exists?(asset)).to be_truthy
      end
    end
  end
end
