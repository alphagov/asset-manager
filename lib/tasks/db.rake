namespace :db do
  task remove_unused_fields_from_assets: :environment do
    if Asset.unscoped.where(access_limited: true).none?
      Asset.update_all('$unset' => { 'access_limited' => true })
      puts 'Asset#access_limited field removed successfully'
    else
      puts 'Error: Unable to remove Asset#access_limited'
    end

    if Asset.unscoped.where(:organisation_slug.ne => nil).none?
      Asset.update_all('$unset' => { 'organisation_slug' => true })
      puts 'Asset#organisation_slug field removed successfully'
    else
      puts 'Error: Unable to remove Asset#organisation_slug'
    end
  end

  desc "Set the size field for all assets from the etag"
  task set_size_for_all_uploaded_assets: :environment do
    scope = Asset.unscoped.where(size: nil)
    processor = AssetProcessor.new(scope: scope)
    processor.process_all_assets_with do |asset_id|
      SetAssetSizeWorker.perform_async(asset_id)
    end
  end

  desc "Transform all redirect chains into one-step redirects"
  task resolve_redirect_chains: :environment do
    replaced = Asset.unscoped.where(:replacement_id.ne => nil)
    replaced.each do |asset|
      next unless asset.replacement.present?
      next if asset.replacement.replacement.present?
      asset.update_indirect_replacements
    end
  end
end
