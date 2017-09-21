require 'rails_helper'

RSpec.describe WhitehallAsset, type: :model do
  describe 'validation' do
    subject(:asset) { FactoryGirl.build(:whitehall_asset, legacy_url_path: nil) }

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
        let(:existing_asset) { FactoryGirl.create(:whitehall_asset) }

        before do
          asset.legacy_url_path = existing_asset.legacy_url_path
        end

        it 'is not valid' do
          expect(asset).not_to be_valid
          expect(asset.errors[:legacy_url_path]).to include('is already taken')
        end
      end
    end
  end

  describe '#legacy_url_path' do
    subject(:asset) { FactoryGirl.build(:whitehall_asset) }

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
        asset.legacy_url_path = '/government/uploads/another-asset.png'
        asset.save!
        expect(asset.reload.legacy_url_path).to eq('/government/uploads/asset.png')
      end
    end
  end

  describe '#public_url_path' do
    subject(:asset) { WhitehallAsset.new(legacy_url_path: '/legacy-url-path') }

    it 'returns legacy URL path for whitehall asset' do
      expect(asset.public_url_path).to eq('/legacy-url-path')
    end
  end

  describe '#mainstream?' do
    let(:asset) { WhitehallAsset.new }

    it 'returns false-y' do
      expect(asset).not_to be_mainstream
    end
  end
end
