class ContentDispositionConfiguration
  attr_reader :type

  def initialize(type:)
    @type = type
  end

  def options_for(asset)
    { filename: filename_for(asset), disposition: type }
  end

private

  def filename_for(asset)
    File.basename(asset.file.path)
  end
end
