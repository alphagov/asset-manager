require 'rails_helper'

RSpec.describe WhitehallAsset, type: :model do
  describe 'validation' do
    subject(:asset) { FactoryBot.build(:whitehall_asset, legacy_url_path: nil) }

    context 'when legacy_url_path is not set' do
      it 'is not valid' do
        expect(asset).not_to be_valid
        expect(asset.errors[:legacy_url_path]).to include("can't be blank")
      end
    end

    context 'when legacy_url_path is set' do
      context 'and legacy_url_path starts with /government/uploads' do
        before do
          asset.legacy_url_path = '/government/uploads/asset.png'
        end

        it 'is valid' do
          expect(asset).to be_valid
        end
      end

      context 'and legacy_url_path does not start with /government/uploads' do
        before do
          asset.legacy_url_path = '/not-government/uploads/asset.png'
        end

        it 'is not valid' do
          expect(asset).not_to be_valid
          expect(asset.errors[:legacy_url_path]).to include('must start with /government/uploads')
        end
      end

      context 'and legacy_url_path is not unique' do
        let!(:existing_asset) { FactoryBot.create(:whitehall_asset) }

        before do
          asset.legacy_url_path = existing_asset.legacy_url_path
        end

        it 'is not valid' do
          expect(asset).not_to be_valid
          expect(asset.errors[:legacy_url_path]).to include('is already taken')
        end

        context 'but the existing asset has been marked as deleted' do
          before do
            asset.legacy_url_path = existing_asset.legacy_url_path
            existing_asset.delete
            asset.save
          end

          it 'is valid because legacy_url_path is unique within the assets not marked as deleted' do
            expect(asset).to be_valid
          end

          it 'can find the most recent (undeleted) asset' do
            path = asset.legacy_url_path[1..-1]
            expect(described_class.from_params(path: path).deleted?).to eq(false)
          end
        end
      end
    end
  end

  describe '#legacy_url_path' do
    subject(:asset) { FactoryBot.build(:whitehall_asset) }

    before do
      asset.legacy_url_path = '/government/uploads/asset.png'
      asset.save!
    end

    context 'when creating asset' do
      it 'can be set' do
        expect(asset.reload.legacy_url_path).to eq('/government/uploads/asset.png')
      end
    end

    context 'when updating asset' do
      it 'cannot be set' do
        expect { asset.legacy_url_path = '/government/uploads/another-asset.png' }.to raise_error(Mongoid::Errors::ReadonlyAttribute)
      end
    end
  end

  describe '#public_url_path' do
    subject(:asset) { described_class.new(legacy_url_path: '/legacy-url-path') }

    it 'returns legacy URL path for whitehall asset' do
      expect(asset.public_url_path).to eq('/legacy-url-path')
    end
  end

  describe '#etag' do
    let(:etag) { 'etag-value' }
    let(:asset) { described_class.new(etag: etag, legacy_etag: legacy_etag) }

    context "when legacy_etag attribute is set" do
      let(:legacy_etag) { 'legacy-etag-value' }

      it "returns legacy_etag attribute value" do
        expect(asset.etag).to eq(legacy_etag)
      end
    end

    context "when legacy_etag attribute is not set" do
      let(:legacy_etag) { nil }

      it "returns Asset#etag attribute value" do
        expect(asset.etag).to eq(etag)
      end
    end
  end

  describe '#last_modified' do
    let(:asset) { described_class.new(last_modified: last_modified, legacy_last_modified: legacy_last_modified) }
    let(:last_modified) { Time.parse('2001-01-01 01:01') }

    context "when legacy_last_modified attribute is set" do
      let(:legacy_last_modified) { Time.parse('2002-02-02 02:02') }

      it "returns legacy_last_modified attribute value" do
        expect(asset.last_modified).to eq(legacy_last_modified)
      end
    end

    context "when legacy_last_modified attribute is not set" do
      let(:legacy_last_modified) { nil }

      it "returns Asset#last_modified attribute value" do
        expect(asset.last_modified).to eq(last_modified)
      end
    end
  end

  describe '#mainstream?' do
    let(:asset) { described_class.new }

    it 'returns false-y' do
      expect(asset).not_to be_mainstream
    end
  end

  describe '.from_params' do
    let(:format_from_params) { 'png' }
    let(:path_from_params) { 'government/uploads/path/to/asset' }
    let(:legacy_url_path) { "/#{path_from_params}.#{format_from_params}" }
    let!(:asset) { FactoryBot.create(:whitehall_asset, legacy_url_path: legacy_url_path) }

    it 'finds Whitehall asset by legacy_url_path' do
      found_asset = described_class.from_params(
        path: path_from_params, format: format_from_params
      )
      expect(found_asset).to eq(asset)
    end

    context 'when format is not specified' do
      let(:legacy_url_path) { "/#{path_from_params}" }

      it 'finds Whitehall asset by legacy_url_path not including format' do
        found_asset = described_class.from_params(path: path_from_params)
        expect(found_asset).to eq(asset)
      end
    end

    context 'when path_prefix is specified' do
      it 'finds Whitehall asset by legacy_url_path including path_prefix' do
        found_asset = described_class.from_params(
          path: 'path/to/asset', format: format_from_params,
          path_prefix: 'government/uploads/'
        )
        expect(found_asset).to eq(asset)
      end
    end
  end

  describe 'soft deletion' do
    let(:asset) { FactoryBot.create(:whitehall_asset) }

    before do
      asset.destroy
    end

    it 'adds a deleted_at timestamp to the record' do
      expect(asset.deleted_at).not_to be_nil
    end

    it 'is not inclued in the "undeleted" scope' do
      expect(Asset.undeleted).not_to include(asset)
    end

    it 'is included in the "deleted" scope' do
      expect(Asset.deleted).to include(asset)
    end

    it 'can be restored' do
      asset.destroy
      expect(asset.deleted_at).not_to be_nil
      asset.restore
      expect(asset.deleted_at).to be_nil
    end
  end
end
