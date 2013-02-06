module FileHelpers
  def load_fixture_file(path)
    File.open( Rails.root.join("spec", "fixtures", "files", path) )
  end
end
RSpec.configuration.include FileHelpers, :type => :model

module ControllerFileHelpers
  def load_fixture_file(path)
    Rack::Test::UploadedFile.new Rails.root.join("spec", "fixtures", "files", path)
  end
end
RSpec.configuration.include ControllerFileHelpers, :type => :controller
RSpec.configuration.include ControllerFileHelpers, :type => :request
