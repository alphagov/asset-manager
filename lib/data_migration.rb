class DataMigration
  def self.add_uuid_to_assets
    Asset.where(uuid: nil).each do |asset|
      asset.uuid = SecureRandom.uuid
      asset.save
    end
  end
end
