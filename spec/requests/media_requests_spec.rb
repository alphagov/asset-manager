require "rails_helper"

RSpec.describe "Media requests", type: :request do
  describe "requesting an asset that doesn't exist" do
    it "should respond with not found status" do
      get "/media/34/test.jpg"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "request an asset to be streamed from S3", disable_cloud_storage_stub: true do
    context "when bucket not configured" do
      let(:asset) { FactoryGirl.create(:clean_asset) }

      before do
        allow(AssetManager).to receive(:aws_s3_bucket_name).and_return(nil)
      end

      it "should respond with internal server error status" do
        get "/media/#{asset.id}/asset.png?stream_from_s3=true"
        expect(response).to have_http_status(:internal_server_error)
      end

      it "should include error message in JSON response" do
        get "/media/#{asset.id}/asset.png?stream_from_s3=true"
        json = JSON.parse(response.body)
        status = json['_response_info']['status']
        expect(status).to eq('Internal server error: AWS S3 bucket not correctly configured')
      end
    end
  end

  describe "request an asset that does exist" do
    let(:asset) { FactoryGirl.create(:clean_asset) }

    before do
      get "/media/#{asset.id}/asset.png", nil, "HTTP_X_SENDFILE_TYPE" => "X-Accel-Redirect",
        "HTTP_X_ACCEL_MAPPING" => "#{Rails.root}/tmp/test_uploads/assets/=/raw/"
    end

    it "should set the X-Accel-Redirect header" do
      expect(response).to be_success
      id = asset.id.to_s
      expect(response.headers["X-Accel-Redirect"]).to eq("/raw/#{id[2..3]}/#{id[4..5]}/#{id}/#{asset.file.identifier}")
    end

    it "should set the correct content headers" do
      expect(response.headers["Content-Type"]).to eq("image/png")
      expect(response.headers["Content-Disposition"]).to eq('inline; filename="asset.png"')
    end
  end
end
