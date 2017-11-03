class AssetProcessor
  def process_all_assets_with
    STDOUT.sync = true
    asset_ids = Asset.pluck(:id).to_a
    total = asset_ids.count
    asset_ids.each_with_index do |asset_id, index|
      percent = "%0.0f" % (index / total.to_f * 100)
      if (index % 1000).zero?
        puts "#{index} of #{total} (#{percent}%) assets"
      end
      yield asset_id.to_s
    end
    puts "\nFinished!"
  end
end
