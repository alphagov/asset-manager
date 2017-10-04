namespace :assets do
  desc 'Store values generated from file metadata for all assets'
  task store_values_generated_from_file_metadata: :environment do
    Asset.all.each do |asset|
      asset.set(
        etag: asset.etag_from_file,
        last_modified: asset.last_modified_from_file,
        md5_hexdigest: asset.md5_hexdigest_from_file
      )
    end
  end
end
