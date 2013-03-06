module FileHelpers
  def load_fixture_file(path)
    File.open( Rails.root.join("spec", "fixtures", "files", path) )
  end
end
RSpec.configuration.include FileHelpers, :type => :model

module ControllerFileHelpers
  def load_fixture_file(path)
    Rack::Test::UploadedFile.new fixture_file_path(path)
  end

  def fixture_file_path(filename)
    Rails.root.join("spec", "fixtures", "files", filename)
  end
end
RSpec.configuration.include ControllerFileHelpers, :type => :controller
RSpec.configuration.include ControllerFileHelpers, :type => :request
