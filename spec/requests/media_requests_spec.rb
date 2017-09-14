require "rails_helper"

RSpec.describe "Media requests", type: :request do
  describe "requesting an asset that doesn't exist" do
    it "should respond with not found status" do
      get "/media/34/test.jpg"
      expect(response).to have_http_status(:not_found)
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
