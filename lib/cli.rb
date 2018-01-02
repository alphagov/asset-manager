class CLI
  def initialize(output = STDOUT, kernel = Kernel)
    @output = output
    @kernel = kernel
  end

  def create_asset(*argv)
    filename = argv[0]

    unless filename
      @output.puts "You need to provide a filename as first argument when running this script"
      @kernel.abort
    end

    file = File.new(filename)
    asset = Asset.new(file: file)

    if asset.save
      @output.puts "Saved!"
      @output.puts "Asset id: #{asset.id}"
      @output.puts "Asset name: #{asset.file.filename}"
      @output.puts "Asset basepath: /media/#{asset.id}/#{asset.file.filename}"
    else
      @output.puts "Not saved, error messages:"
      @output.puts asset.errors.full_messages
    end
  end

  def update_asset(*argv)
    old_asset_id = argv[0]
    filename = argv[1]

    unless old_asset_id
      @output.puts "You need to provide the asset ID as first argument when running this script"
      @kernel.abort
    end

    unless filename
      @output.puts "You need to provide a filename as second argument when running this script"
      @kernel.abort
    end

    file = File.new(filename)
    old_asset = Asset.find(old_asset_id)

    if old_asset.update_attributes(file: file)
      @output.puts "Updated!"
      @output.puts "Asset id: #{old_asset.id}"
      @output.puts "Asset name: #{old_asset.file.filename}"
      @output.puts "Asset basepath: /media/#{old_asset.id}/#{old_asset.file.filename}"
    else
      @output.puts "not updated, something went wrong"
      @output.puts "errors: #{old_asset.errors.full_messages}"
    end
  end
end
