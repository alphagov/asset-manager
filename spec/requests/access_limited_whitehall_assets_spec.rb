require "rails_helper"

RSpec.describe "Access limited Whitehall assets", type: :request do
  let(:user_1) { FactoryBot.create(:user, uid: 'user-1-id') }
  let(:user_2) { FactoryBot.create(:user, uid: 'user-2-id') }
  let(:asset) { FactoryBot.create(:uploaded_whitehall_asset, draft: true, access_limited: ['user-1-id']) }

  before do
    host! AssetManager.govuk.draft_assets_host
  end

  it 'are accessible to users who are authorised to view them' do
    login_as user_1

    get asset.legacy_url_path

    expect(response).to be_successful
  end

  it 'are not accessible to users who are not authorised to view them' do
    login_as user_2

    get asset.legacy_url_path

    expect(response).to be_forbidden
  end
end
