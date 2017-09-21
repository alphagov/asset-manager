require "rails_helper"

RSpec.describe "Virus scanning of uploaded images", type: :request do
  before do
    login_as_stub_user
  end

  specify "uploading a clean asset, and seeing it available after virus scanning" do
    post "/assets", asset: { file: load_fixture_file("lorem.txt") }
    expect(response).to have_http_status(:created)

    asset = Asset.last

    asset_details = JSON.parse(response.body)
    expect(asset_details["id"]).to match(%r{http://www.example.com/assets/#{asset.id}})

    get "/media/#{asset.id}/lorem.txt"
    expect(response).to have_http_status(:not_found)

    VirusScanWorker.drain

    get "/media/#{asset.id}/lorem.txt"
    expect(response).to have_http_status(:success)

    expected = File.read(fixture_file_path("lorem.txt"))
    expect(response.body).to eq(expected)
  end

  # Extension to UploadedFile to represent an uploaded virus
  # without having to have a 'virus' committed into source control.
  #
  # This is using the EICAR test virus (details: http://www.eicar.org/86-0-Intended-use.html)
  class UploadedVirus < Rack::Test::UploadedFile
    def initialize
      @content_type = "text/plain"
      @original_filename = 'eicar.com'

      @tempfile = Tempfile.new(@original_filename)
      @tempfile.set_encoding(Encoding::BINARY) if @tempfile.respond_to?(:set_encoding)

      @tempfile.write 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STAN'
      @tempfile.write 'DARD-ANTIVIRUS-TEST-FILE!$H+H*'
      @tempfile.rewind
    end
  end

  specify "uploading an infected asset, and not seeing it available after virus scanning" do
    post "/assets", asset: { file: UploadedVirus.new }
    expect(response).to have_http_status(:created)

    asset = Asset.last

    asset_details = JSON.parse(response.body)
    expect(asset_details["id"]).to match(%r{http://www.example.com/assets/#{asset.id}})

    get "/media/#{asset.id}/eicar.com"
    expect(response).to have_http_status(:not_found)

    VirusScanWorker.drain

    get "/media/#{asset.id}/eicar.com"
    expect(response).to have_http_status(:not_found)
  end
end
