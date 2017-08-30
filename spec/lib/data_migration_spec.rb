require 'rails_helper'
require 'data_migration'

RSpec.describe DataMigration do
  let!(:unmigrated_asset) { FactoryGirl.create(:asset, uuid: 'some-uuid') }
  let!(:migrated_asset) { FactoryGirl.create(:asset) }

  describe 'add_uuid_to_assets' do
    it 'generates a new uuid for assets with a blank uuid' do
      DataMigration.add_uuid_to_assets

      migrated_asset.reload
      expect(migrated_asset.uuid).to_not be_blank
    end

    it 'does not generate a new uuid for an asset when one already exists' do
      DataMigration.add_uuid_to_assets

      unmigrated_asset.reload
      expect(unmigrated_asset.uuid).to eq('some-uuid')
    end
  end
end
