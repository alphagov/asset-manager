namespace :assets do
  desc "Mark an asset as deleted and (optionally) remove from S3"
  task :delete, %i[id permanent] => :environment do |_t, args|
    asset = Asset.find(args.fetch(:id))
    asset.destroy!
    Services.cloud_storage.delete(asset) if args[:permanent]
  end

  desc "Mark a Whitehall asset as deleted and (optionally) remove from S3"
  task :whitehall_delete, %i[legacy_url_path permanent] => :environment do |_t, args|
    asset = WhitehallAsset.find_by!(legacy_url_path: args.fetch(:legacy_url_path))
    Rake::Task["assets:delete"].invoke(asset.id, args[:permanent])
  end

  desc "Mark an asset as a redirect"
  task :redirect, %i[id redirect_url] => :environment do |_t, args|
    asset = Asset.find(args.fetch(:id))
    redirect_url = args.fetch(:redirect_url)
    abort "redirect_url must start with https://" unless redirect_url.start_with? "https://"
    asset.update!(redirect_url:, deleted_at: nil)
  end

  desc "Mark a Whitehall asset as a redirect"
  task :whitehall_redirect, %i[legacy_url_path redirect_url] => :environment do |_t, args|
    asset = WhitehallAsset.find_by!(legacy_url_path: args.fetch(:legacy_url_path))
    Rake::Task["assets:redirect"].invoke(asset.id, args.fetch(:redirect_url))
  end

  desc "Get a Whitehall asset's ID by its legacy_url_path, e.g. /government/uploads/system/uploads/attachment_data/file/1234/document.pdf"
  task :get_id_by_legacy_url_path, %i[legacy_url_path] => :environment do |_t, args|
    legacy_url_path = args.fetch(:legacy_url_path)
    asset = WhitehallAsset.find_by!(legacy_url_path:)
    puts "Asset ID for #{legacy_url_path} is #{asset.id}."
  end

  desc "Soft delete assets and check deleted invalid state"
  task :bulk_soft_delete, %i[csv_path] => :environment do |_t, args|
    csv_path = args.fetch(:csv_path)

    CSV.foreach(csv_path, headers: false) do |row|
      asset_id = row[0]
      asset = Asset.find(asset_id)
      asset.state = "uploaded" if asset.state == "deleted"

      begin
        asset.destroy!
        print "."
      rescue Mongoid::Errors::Validations
        puts "Failed to delete asset of ID #{asset_id}: #{asset.errors.full_messages}"
      end
    end
  end

  desc "Publish draft replacement asset"
  task :publish_draft_replacement, %i[replacement_id apply] => :environment do |_t, args|
    replacement_id = args.fetch(:replacement_id)
    dry_run = args[:apply] != "true"
    config = GovukConfiguration.new
    live_host = config.assets_host

    if dry_run
      puts "DRY RUN MODE - No changes will be saved"
      puts "To apply changes, run: rake assets:publish_draft_replacement[#{replacement_id},true]"
    end

    replacement = Asset.find_by(id: replacement_id)
    next puts "SKIP - Replacement #{replacement_id} already published" unless replacement.draft?

    if dry_run
      puts "DRY RUN - Would publish replacement #{replacement_id}"
      if replacement.parent_document_url&.include?("draft-origin")
        new_url = replacement.parent_document_url.sub(%r{draft-origin\.[^/]+}, live_host)
        puts "DRY RUN - Would update URL from '#{replacement.parent_document_url}' to '#{new_url}'"
      end
    else
      replacement.draft = false

      if replacement.parent_document_url&.include?("draft-origin")
        replacement.parent_document_url = replacement.parent_document_url.sub(%r{draft-origin\.[^/]+}, live_host)
      end

      if replacement.save
        puts "OK - Replacement #{replacement_id} published"
      else
        abort "ERROR - #{replacement.errors.full_messages.join(', ')}"
      end
    end
  end

  namespace :bulk_fix do
    desc "Fix assets and draft replacements"
    task :fix_assets_and_draft_replacements, %i[csv_path] => :environment do |_t, args|
      csv_path = args.fetch(:csv_path)

      processed_asset_ids = {}

      process_file_in_memory(csv_path) do |row|
        original_asset_id = row[0]
        original_asset = Asset.where(_id: original_asset_id)&.first
        is_replacement = Asset.where(replacement_id: original_asset_id).any?

        if original_asset.nil?
          puts "Asset ID: #{original_asset_id} - SKIPPED. No asset found."
          next
        end

        replacement_asset = original_asset.replacement

        if replacement_asset && processed_asset_ids[replacement_asset.id.to_s]
          puts "Asset ID: #{original_asset_id} - PROCESSED. Replacement #{replacement_asset.id} already processed."
          next
        end

        if replacement_asset&.draft?
          begin
            delete_and_update_draft(replacement_asset)
            processed_asset_ids[replacement_asset.id.to_s] = true
            puts "Asset ID: #{original_asset_id} - OK. Draft replacement #{replacement_asset.id} deleted and updated to false."
          rescue StandardError => e
            message = replacement_asset.errors.full_messages.empty? ? e.message : replacement_asset.errors.full_messages
            puts "Asset ID: #{original_asset_id} - ERROR. Asset replacement #{replacement_asset.id} failed to save. Error: #{message}."
          end
          next
        end

        if is_replacement && replacement_asset.nil? && original_asset.draft?
          begin
            delete_and_update_draft(original_asset)
            processed_asset_ids[original_asset_id] = true
            puts "Asset ID: #{original_asset_id} - OK. Asset is a replacement. Asset deleted and updated to false."
          rescue StandardError => e
            message = original_asset.errors.full_messages.empty? ? e.message : original_asset.errors.full_messages
            puts "Asset ID: #{original_asset_id} - ERROR. Asset failed to save. Error: #{message}."
          end
          next
        end

        if processed_asset_ids[original_asset_id]
          puts "Asset ID: #{original_asset_id} - PROCESSED. Asset already processed."
          next
        end

        if original_asset.deleted? || replacement_asset || original_asset.redirect_url
          puts "Asset ID: #{original_asset_id} - SKIPPED. Asset is draft (#{original_asset.draft?}), deleted (#{original_asset.deleted?}), replaced (#{!replacement_asset.nil?}), or redirected (#{!original_asset.redirect_url.nil?})."
          next
        end

        begin
          delete_and_update_draft(original_asset, should_update_draft: false)
          processed_asset_ids[original_asset_id] = true
          puts "Asset ID: #{original_asset_id} - OK. Asset has been deleted."
        rescue StandardError => e
          message = original_asset.errors.full_messages.empty? ? e : original_asset.errors.full_messages
          puts "Asset ID: #{original_asset_id} - ERROR. Asset failed to save. Error: #{message}."
        end
      end
    end
  end
end

def delete_and_update_draft(asset, should_update_draft: true)
  if asset.state.to_s == "deleted"
    asset.state = "uploaded"
    puts "Patched state: #{asset.id}"
  end

  if asset.parent_document_url&.include?("draft-origin")
    asset.parent_document_url = nil
    puts "Patched Parent URL: #{asset.id}"
  end

  asset.destroy! unless asset.deleted?

  return unless should_update_draft

  asset.draft = false
  asset.save!
end

def process_file_in_memory(filepath)
  File.open(filepath, "r+") do |file|
    lines = file.readlines
    file.rewind

    lines.each do |line|
      row = line.split(",").map(&:strip)
      if row.last == "DONE"
        file.puts line
        next
      end

      yield row

      file.puts "#{line.strip},DONE\n"
    end
  end
end
