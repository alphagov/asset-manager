class CLI
  def initialize(output = $stdout, kernel = Kernel)
    @output = output
    @kernel = kernel
  end

  def create_asset(*argv)
    filename = argv[0]

    unless filename
      puts "You need to provide a filename as first argument when running this script"
      abort # rubocop:disable Rails/Exit
    end

    file = File.new(filename)
    asset = Asset.new(file:)

    if asset.save
      puts "Saved!"
      puts "Asset id: #{asset.id}"
      puts "Asset name: #{asset.file.filename}"
      puts "Asset basepath: /media/#{asset.id}/#{asset.file.filename}"
    else
      puts "Not saved, error messages:"
      puts asset.errors.full_messages
    end
  end

  def update_asset(*argv)
    old_asset_id = argv[0]
    filename = argv[1]

    unless old_asset_id
      puts "You need to provide the asset ID as first argument when running this script"
      abort # rubocop:disable Rails/Exit
    end

    unless filename
      puts "You need to provide a filename as second argument when running this script"
      abort # rubocop:disable Rails/Exit
    end

    file = File.new(filename)
    old_asset = Asset.find(old_asset_id)

    if old_asset.update(file:)
      puts "Updated!"
      puts "Asset id: #{old_asset.id}"
      puts "Asset name: #{old_asset.file.filename}"
      puts "Asset basepath: /media/#{old_asset.id}/#{old_asset.file.filename}"
    else
      puts "not updated, something went wrong"
      puts "errors: #{old_asset.errors.full_messages}"
    end
  end

private

  def puts(*messages)
    @output.puts(*messages)
  end

  def abort(message = nil)
    @kernel.abort(message)
  end
end
