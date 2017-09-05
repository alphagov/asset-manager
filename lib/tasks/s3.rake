namespace :s3 do
  desc "Upload clean assets to S3 (percentage: fraction of assets to upload; default: 0)"
  task :upload_all_clean_assets, [:percentage] => [:environment] do |_t, args|
    count = 0
    random_number_generator = Random.new
    Asset.where(state: 'clean').each do |asset|
      if asset.file.file.exists?
        if random_number_generator.rand(100) < args[:percentage].to_i
          asset.delay(priority: 10).save_to_cloud_storage
          count += 1
        end
      else
        puts "Ignoring asset (#{asset.id}) with missing file: #{asset.file.file.path}"
      end
    end
    puts "Total jobs enqueued: #{count}"
  end
end
