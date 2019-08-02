require "rails_helper"

RSpec.describe "Access limited assets", type: :request do
  let(:user_1) { FactoryBot.create(:user, uid: 'user-1-id') }
  let(:user_2) { FactoryBot.create(:user, uid: 'user-2-id') }
  let(:user_3) { FactoryBot.create(:user, uid: 'user-3-id', organisation_content_id: 'org-a') }
  let(:user_4) { FactoryBot.create(:user, uid: 'user-4-id', organisation_content_id: 'org-b') }
  let(:asset) { FactoryBot.create(:uploaded_asset, draft: true, access_limited: ['user-1-id'], access_limited_organisation_ids: ['org-a']) }

  before do
    host! AssetManager.govuk.draft_assets_host
  end

  it 'are accessible to users who are authorised to view them' do
    login_as user_1

    get download_media_path(id: asset, filename: asset.filename)

    expect(response).to be_successful
  end

  it 'are not accessible to users who are not authorised to view them' do
    login_as user_2

    get download_media_path(id: asset, filename: asset.filename)

    expect(response).to be_forbidden
  end

  it 'are accessible to users in organisations authorised to view them' do
    login_as user_3

    get download_media_path(id: asset, filename: asset.filename)

    expect(response).to be_successful
  end

  it 'are not accessible to users in organisations not authorised to view them' do
    login_as user_4

    get download_media_path(id: asset, filename: asset.filename)

    expect(response).to be_forbidden
  end
end
