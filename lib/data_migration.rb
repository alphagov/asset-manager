class DataMigration
  def self.add_uuid_to_assets
    Asset.where(uuid: nil).each do |asset|
      asset.update_attribute(:uuid, SecureRandom.uuid)
    end
  end
end
