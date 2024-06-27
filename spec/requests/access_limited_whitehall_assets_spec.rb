require "rails_helper"

RSpec.describe "Access limited Whitehall assets", type: :request do
  let(:authorised_user) { FactoryBot.create(:user, uid: "user-1-id") }
  let(:unauthorised_user) { FactoryBot.create(:user, uid: "user-2-id") }
  let(:asset) { FactoryBot.create(:uploaded_whitehall_asset, draft: true, access_limited: ["user-1-id"]) }
  let(:s3) { S3Configuration.build }

  before do
    allow(AssetManager).to receive(:s3).and_return(s3)
    allow(s3).to receive(:fake?).and_return(false)
    host! AssetManager.govuk.draft_assets_host
  end

  it "are accessible to users who are authorised to view them" do
    login_as authorised_user

    get asset.legacy_url_path

    expect(response).to be_successful
  end

  it "are not accessible to users who are not authorised to view them" do
    login_as unauthorised_user

    get asset.legacy_url_path

    expect(response).to be_forbidden
  end
end
