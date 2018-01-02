class CLI
  def initialize(output = STDOUT, kernel = Kernel)
    @output = output
    @kernel = kernel
  end

  def create_asset(*argv)
    filename = argv.any? ? argv.fetch(0) : nil

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
end
