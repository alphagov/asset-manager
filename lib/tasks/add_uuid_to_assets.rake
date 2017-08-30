require 'data_migration'

namespace :migrate do
  desc "Populate the UUID field for all Assets if it is blank"
  task :add_uuid_to_assets => :environment do
    DataMigration.add_uuid_to_assets
  end
end
