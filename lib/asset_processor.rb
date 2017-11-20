class AssetProcessor
  def initialize(output: STDOUT, report_progress_every: 1000)
    @output = output
    @report_progress_every = report_progress_every
  end

  def process_all_assets_with
    @output.sync = true
    asset_ids = Asset.pluck(:id).to_a
    total = asset_ids.count
    asset_ids.each_with_index do |asset_id, index|
      count = index + 1
      percent = "%0.0f" % (count / total.to_f * 100)
      if (count % @report_progress_every).zero?
        @output.puts "#{count} of #{total} (#{percent}%) assets"
      end
      yield asset_id.to_s
    end
    @output.puts "\nFinished!"
  end
end
