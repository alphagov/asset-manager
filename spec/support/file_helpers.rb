module FileHelpers
  def load_fixture_file(path, named: nil)
    Rack::Test::UploadedFile.new(fixture_file_path(path)).tap do |file|
      if named.present?
        file.instance_variable_set(:@original_filename, named)
      end
    end
  end

  def fixture_file_path(filename)
    Rails.root.join("spec", "fixtures", "files", filename)
  end
end
RSpec.configuration.include FileHelpers, type: :model
RSpec.configuration.include FileHelpers, type: :controller
RSpec.configuration.include FileHelpers, type: :request
