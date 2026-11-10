class RequeueUnscannedAssetsJob
  include Sidekiq::Job

  DEFAULT_AGE_MINUTES = 30
  DEFAULT_BATCH_SIZE = 500

  sidekiq_options queue: "low_priority", lock: :until_executed

  def perform(batch_size = DEFAULT_BATCH_SIZE, age_in_minutes = DEFAULT_AGE_MINUTES)
    @batch_size = batch_size&.to_i
    @age_in_minutes = age_in_minutes&.to_i

    unless @batch_size.positive?
      raise ArgumentError, "Invalid batch size for requeueing unscanned assets: #{@batch_size.inspect}"
    end

    unless @age_in_minutes.positive?
      raise ArgumentError, "Invalid age in minutes for requeueing unscanned assets: #{@age_in_minutes.inspect}"
    end

    process_assets
  end

private

  attr_reader :age_in_minutes, :batch_size

  def process_assets
    assets_with_files, assets_missing_files = assets.group_by { |asset|
      File.exist?(asset.file.path)
    }.values_at(true, false)

    message = if assets_with_files.present?
                count = assets_with_files.size
                "Enqueueing #{count} unscanned #{'asset'.pluralize(count)} for virus scanning"
              else
                "No unscanned assets older than #{age_in_minutes} minutes found"
              end
    Rails.logger.info("#{self.class.name} - #{message}")

    assets_with_files&.each(&:schedule_virus_scan)

    message = if assets_missing_files.present?
                count = assets_missing_files.size
                "Removing #{count} unscanned #{'asset'.pluralize(count)} with #{count == 1 ? 'its' : 'their'} file missing"
              else
                "No unscanned assets without file found"
              end
    Rails.logger.info("#{self.class.name} - #{message}")

    assets_missing_files&.each do |asset|
      asset.destroy!
      Services.cloud_storage.delete(asset)
    end
  end

  def assets
    Asset
      .where(
        state: "unscanned",
        deleted_at: nil,
        redirect_url: nil,
        updated_at: { "$lt" => age_in_minutes.minutes.ago },
      )
      .limit(batch_size)
      .to_a
  end
end
