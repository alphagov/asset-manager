require "rails_helper"

RSpec.describe AssetsController, type: :controller do
  render_views # for json responses

  let(:file) { load_fixture_file("asset.png") }

  before do
    login_as_stub_user
  end

  describe "POST create" do
    let(:valid_attributes) { { file: } }

    context "when attributes are valid" do
      it "persists asset" do
        post :create, params: { asset: valid_attributes }

        expect(assigns(:asset)).to be_persisted
      end

      it "stores file on asset" do
        post :create, params: { asset: valid_attributes }

        expect(assigns(:asset).file.path).to match(/asset\.png$/)
      end

      it "stores access_limited_user_ids as access_limited on asset" do
        attributes = valid_attributes.merge(access_limited_user_ids: %w[user-id])
        post :create, params: { asset: attributes }

        expect(assigns(:asset).access_limited).to eq(%w[user-id])
      end

      it "stores access_limited on asset" do
        attributes = valid_attributes.merge(access_limited: %w[user-id])
        post :create, params: { asset: attributes }

        expect(assigns(:asset).access_limited).to eq(%w[user-id])
      end

      it "stores access_limited blank string as empty array on access_limited" do
        attributes = valid_attributes.merge(access_limited: "")
        post :create, params: { asset: attributes }

        expect(assigns(:asset).access_limited).to eq([])
      end

      it "stores access_limited_user_ids blank string as empty array on access_limited" do
        attributes = valid_attributes.merge(access_limited_user_ids: "")
        post :create, params: { asset: attributes }

        expect(assigns(:asset).access_limited).to eq([])
      end

      it "stores access_limited_organisation_ids on asset" do
        attributes = valid_attributes.merge(access_limited_organisation_ids: %w[org-id])
        post :create, params: { asset: attributes }

        expect(assigns(:asset).access_limited_organisation_ids).to eq(%w[org-id])
      end

      it "stores auth_bypass_ids on asset" do
        attributes = valid_attributes.merge(auth_bypass_ids: %w[id1 id2])
        post :create, params: { asset: attributes }

        expect(assigns(:asset).auth_bypass_ids).to eq(%w[id1 id2])
      end

      it "stores parent_document_url on asset" do
        attributes = valid_attributes.merge(parent_document_url: "parent-document-url")
        post :create, params: { asset: attributes }

        expect(assigns(:asset).parent_document_url).to eq("parent-document-url")
      end

      it "stores a specified content type" do
        attributes = valid_attributes.merge(content_type: "application/pdf")
        post :create, params: { asset: attributes }

        expect(assigns(:asset).content_type).to eq("application/pdf")
      end

      it "responds with created status" do
        post :create, params: { asset: valid_attributes }

        expect(response).to have_http_status(:created)
      end

      it "responds with the details of the new asset" do
        post :create, params: { asset: valid_attributes }

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        expect(body["id"]).to eq("http://test.host/assets/#{asset.id}")
        expect(body["name"]).to eq("asset.png")
        expect(body["content_type"]).to eq("image/png")
        expect(body["draft"]).to be_falsey
      end
    end

    context "when attributes are invalid" do
      let(:invalid_attributes) { { file: nil } }

      it "does not persist asset" do
        post :create, params: { asset: invalid_attributes }

        expect(assigns(:asset)).not_to be_persisted
        expect(assigns(:asset).file.path).to be_nil
      end

      it "responds with unprocessable entity status" do
        post :create, params: { asset: invalid_attributes }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when attributes include draft status" do
      let(:attributes) { valid_attributes.merge(draft: true) }

      it "stores draft status on asset" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset)).to be_draft
      end

      it "includes the draft status in the response" do
        post :create, params: { asset: attributes }

        body = JSON.parse(response.body)

        expect(body["draft"]).to be_truthy
      end
    end

    context "when attributes include a redirect URL" do
      let(:redirect_url) { "https://example.com/path/file.ext" }
      let(:attributes) { valid_attributes.merge(redirect_url:) }

      it "stores redirect URL on asset" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset).redirect_url).to eq(redirect_url)
      end

      context "and redirect URL is blank" do
        let(:redirect_url) { "" }

        it "stores redirect URL as nil" do
          post :create, params: { asset: attributes }

          expect(assigns(:asset).redirect_url).to be_nil
        end
      end
    end

    context "when attributes include a replacement_id" do
      let(:replacement) { FactoryBot.create(:asset) }
      let(:replacement_id) { replacement.id.to_s }
      let(:attributes) { valid_attributes.merge(replacement_id:) }

      it "stores replacement asset" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset).replacement).to eq(replacement)
      end

      context "and replacement_id is blank" do
        let(:replacement_id) { "" }

        it "stores no replacement" do
          post :create, params: { asset: attributes }

          expect(assigns(:asset).replacement).to be_blank
        end

        it "stores replacement_id as nil" do
          post :create, params: { asset: attributes }

          expect(assigns(:asset).replacement_id).to be_nil
        end
      end

      context "and replacement_id does not match an existing asset" do
        let(:replacement_id) { "non-existent-asset-id" }

        it "responds with unprocessable entity status" do
          post :create, params: { asset: attributes }

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "includes error message in response" do
          post :create, params: { asset: attributes }

          body = JSON.parse(response.body)
          status = body["_response_info"]["status"]
          expect(status).to include("Replacement not found")
        end
      end

      it "includes the replacement_id in the response" do
        post :create, params: { asset: attributes }

        body = JSON.parse(response.body)

        expect(body["replacement_id"]).to eq(replacement_id)
      end
    end
  end

  describe "PUT update" do
    context "with an existing asset" do
      let(:asset) { FactoryBot.create(:asset) }
      let(:file) { load_fixture_file("asset2.jpg") }
      let(:valid_attributes) { { file: } }

      it "persists new attributes on existing asset" do
        put :update, params: { id: asset.id, asset: valid_attributes }

        expect(assigns(:asset)).to be_persisted
      end

      it "stores file on existing asset" do
        put :update, params: { id: asset.id, asset: valid_attributes }

        expect(assigns(:asset).file.path).to match(/asset2\.jpg$/)
      end

      it "stores access_limited on existing asset" do
        attributes = valid_attributes.merge(access_limited: %w[user-id])
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).access_limited).to eq(%w[user-id])
      end

      it "resets access_limits for an existing asset with a blank acess_limited_user_ids param" do
        asset.update!(access_limited: %w[user-uid])

        # We have to use an empty string as that is what gds-api-adapters/rest-client
        # will generate instead of an empty array
        attributes = valid_attributes.merge(access_limited_user_ids: "")
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).access_limited).to eq([])
      end

      it "resets access_limits for an existing asset with a blank acess_limited param" do
        asset.update!(access_limited: %w[user-uid])

        # We have to use an empty string as that is what gds-api-adapters/rest-client
        # will generate instead of an empty array
        attributes = valid_attributes.merge(access_limited: "")
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).access_limited).to eq([])
      end

      it "stores access_limited_organisation_ids on existing asset" do
        attributes = valid_attributes.merge(access_limited_organisation_ids: %w[org-id])
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).access_limited_organisation_ids).to eq(%w[org-id])
      end

      it "resets access_limited_organisation_ids to an empty array for an existing asset with an access_limited_organisation_ids array" do
        asset.update!(access_limited_organisation_ids: %w[org-id])

        # We have to use an empty string as that is what gds-api-adapters/rest-client
        # will generate instead of an empty array
        attributes = valid_attributes.merge(access_limited_organisation_ids: "")
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).access_limited_organisation_ids).to eq([])
      end

      it "stores auth_bypass_ids on existing asset" do
        attributes = valid_attributes.merge(auth_bypass_ids: %w[bypass-id])
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).auth_bypass_ids).to eq(%w[bypass-id])
      end

      it "copes when auth_bypass_ids are passed in as an empty string" do
        asset.update!(auth_bypass_ids: %w[bypass-1 bypass-2])

        # We have to use an empty string as that is what gds-api-adapters/rest-client
        # will generate instead of an empty array
        attributes = valid_attributes.merge(auth_bypass_ids: "")
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).auth_bypass_ids).to eq([])
      end

      it "stores redirect_url on existing asset" do
        redirect_url = "https://example.com/path/file.ext"
        attributes = valid_attributes.merge(redirect_url:)
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).redirect_url).to eq(redirect_url)
      end

      it "stores blank redirect_url as nil on existing asset" do
        redirect_url = ""
        attributes = valid_attributes.merge(redirect_url:)
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).redirect_url).to be_nil
      end

      it "removes existing redirect_url from existing asset if empty one is sent" do
        redirect_url = "https://example.com/path/file.ext"
        attributes = valid_attributes.merge(redirect_url:)
        put :update, params: { id: asset.id, asset: attributes }
        expect(assigns(:asset).redirect_url).to eq(redirect_url)

        attributes = valid_attributes.merge(redirect_url: "")
        put :update, params: { id: asset.id, asset: attributes }
        expect(assigns(:asset).redirect_url).to be_nil
      end

      it "stores replacement on existing asset" do
        replacement = FactoryBot.create(:asset)
        replacement_id = replacement.id.to_s
        attributes = valid_attributes.merge(replacement_id:)
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).replacement).to eq(replacement)
      end

      it "stores replacement_id as nil if replacement_id is blank" do
        replacement_id = ""
        attributes = valid_attributes.merge(replacement_id:)
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset).replacement_id).to be_nil
      end

      it "responds with unprocessable entity status if replacement is not found" do
        replacement_id = "non-existent-asset-id"
        attributes = valid_attributes.merge(replacement_id:)
        put :update, params: { id: asset.id, asset: attributes }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "includes error message in response if replacement is not found" do
        replacement_id = "non-existent-asset-id"
        attributes = valid_attributes.merge(replacement_id:)
        put :update, params: { id: asset.id, asset: attributes }

        body = JSON.parse(response.body)
        status = body["_response_info"]["status"]
        expect(status).to include("Replacement not found")
      end

      it "responds with success status" do
        put :update, params: { id: asset.id, asset: valid_attributes }

        expect(response).to have_http_status(:success)
      end

      it "responds with the details of the existing asset" do
        put :update, params: { id: asset.id, asset: valid_attributes }

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        expect(body["id"]).to eq("http://test.host/assets/#{asset.id}")
        expect(body["name"]).to eq("asset2.jpg")
        expect(body["content_type"]).to eq("image/jpeg")
        expect(body["draft"]).to be_falsey
      end

      context "when attributes include draft status" do
        let(:attributes) { valid_attributes.merge(draft: true) }

        it "stores draft status on existing asset" do
          put :update, params: { id: asset.id, asset: attributes }

          expect(assigns(:asset)).to be_draft
        end

        it "includes the draft status in the response" do
          put :update, params: { id: asset.id, asset: attributes }

          body = JSON.parse(response.body)

          expect(body["draft"]).to be_truthy
        end
      end
    end
  end

  describe "DELETE destroy" do
    context "with an existing asset" do
      let(:asset) { FactoryBot.create(:asset) }

      it "deletes the asset" do
        delete :destroy, params: { id: asset.id }

        expect(Asset.where(id: asset.id).first.deleted_at).not_to be_nil
      end

      it "responds with a success status" do
        delete :destroy, params: { id: asset.id }

        expect(response).to have_http_status(:success)
      end
    end

    context "with no existing asset" do
      it "responds with not found status" do
        delete :destroy, params: { id: "12345" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET show" do
    context "with an asset which exists" do
      let(:asset) { FactoryBot.create(:asset) }

      it "responds with success status" do
        get :show, params: { id: asset.id }

        expect(response).to be_successful
      end

      it "makes the asset available to the view template" do
        get :show, params: { id: asset.id }

        expect(assigns(:asset)).to be_a(Asset)
        expect(assigns(:asset).id).to eq(asset.id)
      end

      it "includes the draft status in the response" do
        get :show, params: { id: asset.id }

        body = JSON.parse(response.body)

        expect(body["draft"]).to be_falsey
      end

      it "sets the Cache-Control header to no-cache" do
        get :show, params: { id: asset.id }

        expect(response.headers["Cache-Control"]).to eq("no-cache")
      end
    end

    context "with an asset that has been deleted" do
      let(:asset) { FactoryBot.create(:deleted_asset) }

      it "responds with success status" do
        get :show, params: { id: asset.id }

        expect(response).to be_successful
      end
    end

    context "with no existing asset" do
      it "responds with not found status" do
        get :show, params: { id: "some-gif-or-other" }

        expect(response).to have_http_status(:not_found)
      end

      it "responds with not found message" do
        get :show, params: { id: "some-gif-or-other" }

        body = JSON.parse(response.body)
        expect(body["_response_info"]["status"]).to eq("not found")
      end
    end
  end

  describe "POST restore" do
    context "with an asset marked as deleted" do
      let(:asset) { FactoryBot.create(:asset, deleted_at: 10.minutes.ago) }

      before do
        post :restore, params: { id: asset.id }
      end

      it "responds with success status" do
        expect(response).to be_successful
      end

      it "marks the asset as not deleted" do
        restored_asset = assigns(:asset)
        expect(restored_asset).not_to be_nil
        expect(restored_asset.deleted_at).to be_nil
      end
    end
  end
end
