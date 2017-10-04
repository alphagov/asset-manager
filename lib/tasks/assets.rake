namespace :assets do
  desc 'Store values generated from file metadata for all assets'
  task store_values_generated_from_file_metadata: :environment do
    total = Asset.count
    Asset.all.each_with_index do |asset, index|
      percent = "%0.0f" % (index / total.to_f * 100)
      if (index % 1000).zero?
        puts "#{index} of #{total} (#{percent}%) assets processed"
      end
      asset.set(
        etag: asset.etag_from_file,
        last_modified: asset.last_modified_from_file,
        md5_hexdigest: asset.md5_hexdigest_from_file
      )
    end
    puts "\nFinished!"
    puts "#{Asset.where(etag: nil).count} assets have no etag set"
    puts "#{Asset.where(last_modified: nil).count} assets have no last_modified set"
    puts "#{Asset.where(md5_hexdigest: nil).count} assets have no md5_hexdigest set"
  end
end
