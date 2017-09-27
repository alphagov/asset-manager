namespace :assets do
  desc 'Store etag value generated from file metadata for all assets'
  task store_etag_value_generated_from_file_metadata: :environment do
    Asset.all.each do |asset|
      asset.update!(etag: asset.etag_from_file)
    end
  end
end
