module FileHelpers
  def load_fixture_file(path)
    File.open( File.join(Rails.root, "spec", "fixtures", "files", path) )
  end
end
RSpec.configuration.include FileHelpers, :type => :model
