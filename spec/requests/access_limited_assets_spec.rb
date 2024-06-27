require "rails_helper"

RSpec.describe "Access limited assets", type: :request do
  let(:authorised_user) { FactoryBot.create(:user, uid: "user-1-id") }
  let(:unauthorised_user) { FactoryBot.create(:user, uid: "user-2-id") }
  let(:user_from_authorised_organisation) { FactoryBot.create(:user, uid: "user-3-id", organisation_content_id: "org-a") }
  let(:user_from_unauthorised_organisation) { FactoryBot.create(:user, uid: "user-4-id", organisation_content_id: "org-b") }
  let(:asset) { FactoryBot.create(:uploaded_asset, draft: true, access_limited: ["user-1-id"], access_limited_organisation_ids: %w[org-a]) }
  let(:s3) { S3Configuration.build }

  before do
    allow(AssetManager).to receive(:s3).and_return(s3)
    allow(s3).to receive(:fake?).and_return(false)
    host! AssetManager.govuk.draft_assets_host
  end

  it "are accessible to users who are authorised to view them" do
    login_as authorised_user

    get download_media_path(id: asset, filename: asset.filename)

    expect(response).to be_successful
  end

  it "are not accessible to users who are not authorised to view them" do
    login_as unauthorised_user

    get download_media_path(id: asset, filename: asset.filename)

    expect(response).to be_forbidden
  end

  it "are accessible to users in organisations authorised to view them" do
    login_as user_from_authorised_organisation

    get download_media_path(id: asset, filename: asset.filename)

    expect(response).to be_successful
  end

  it "are not accessible to users in organisations not authorised to view them" do
    login_as user_from_unauthorised_organisation

    get download_media_path(id: asset, filename: asset.filename)

    expect(response).to be_forbidden
  end
end
