require "spec_helper"

describe "Virus scanning of uploaded images" do
  before :each do
    login_as_stub_user
  end

  specify "uploading a clean asset, and seeing it available after virus scanning" do
    # post "/assets", :asset => { :file => load_fixture_file("lorem.txt") }
    # response.status.should == 201
    # 
    # @asset = Asset.last
    # 
    # asset_details = JSON.parse(response.body)
    # asset_details["id"].should =~ %r{http://www.example.com/assets/#{@asset.id}}
    # 
    # get "/media/#{@asset.id}/lorem.txt"
    # response.status.should == 404
    # 
    # 
    # run_all_delayed_jobs
    # 
    # get "/media/#{@asset.id}/lorem.txt"
    # 
    # response.status.should == 200
    # 
    # expected = File.read(fixture_file_path("lorem.txt"))
    # response.body.should == expected
  end

  # Extension to UploadedFile to represent an uploaded virus
  # without having to have a 'virus' committed into source control.
  #
  # This is using the EICAR test virus (details: http://www.eicar.org/86-0-Intended-use.html)
  class UploadedVirus < Rack::Test::UploadedFile
    def initialize()
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
    # post "/assets", :asset => { :file => UploadedVirus.new }
    # response.status.should == 201
    # 
    # @asset = Asset.last
    # 
    # asset_details = JSON.parse(response.body)
    # asset_details["id"].should =~ %r{http://www.example.com/assets/#{@asset.id}}
    # 
    # get "/media/#{@asset.id}/eicar.com"
    # response.status.should == 404
    # 
    # run_all_delayed_jobs
    # 
    # get "/media/#{@asset.id}/eicar.com"
    # response.status.should == 404
  end
end
