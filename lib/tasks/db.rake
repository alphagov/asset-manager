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
end
