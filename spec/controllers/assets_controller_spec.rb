require 'rails_helper'

RSpec.describe AssetsController, type: :controller do
  render_views # for json responses

  let(:file) { load_fixture_file('asset.png') }

  before do
    login_as_stub_user
  end

  describe 'POST create' do
    context 'when attributes are valid' do
      let(:attributes) { { file: file } }

      it 'persists asset' do
        post :create, params: { asset: attributes }

        expect(assigns(:asset)).to be_persisted
        expect(assigns(:asset).file.path).to match(/asset\.png$/)
      end

      it 'responds with created status' do
        post :create, params: { asset: attributes }

        expect(response).to have_http_status(:created)
      end

      it 'stores access_limited on asset' do
        post :create, params: { asset: attributes.merge(access_limited: ['user-id']) }

        expect(assigns(:asset).access_limited).to eq(['user-id'])
      end

      it 'responds with the details of the new asset' do
        post :create, params: { asset: attributes }

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        expect(body['id']).to eq("http://test.host/assets/#{asset.id}")
        expect(body['name']).to eq('asset.png')
        expect(body['content_type']).to eq('image/png')
        expect(body['draft']).to be_falsey
      end
    end

    context 'when attributes are invalid' do
      let(:attributes) { { file: nil } }

      it 'does not persist asset' do
        post :create, params: { asset: attributes }

        expect(assigns(:asset)).not_to be_persisted
        expect(assigns(:asset).file.path).to be_nil
      end

      it 'responds with unprocessable entity status' do
        post :create, params: { asset: attributes }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when attributes include draft status' do
      let(:attributes) { { draft: true, file: file } }

      it 'stores draft status on asset' do
        post :create, params: { asset: attributes }

        expect(assigns(:asset)).to be_draft
      end

      it 'includes the draft status in the response' do
        post :create, params: { asset: attributes }

        body = JSON.parse(response.body)

        expect(body['draft']).to be_truthy
      end
    end

    context 'when attributes include a redirect URL' do
      let(:redirect_url) { 'https://example.com/path/file.ext' }
      let(:attributes) { { redirect_url: redirect_url, file: file } }

      it 'stores redirect URL on asset' do
        post :create, params: { asset: attributes }

        expect(assigns(:asset).redirect_url).to eq(redirect_url)
      end

      context 'and redirect URL is blank' do
        let(:redirect_url) { '' }

        it 'stores redirect URL as nil' do
          post :create, params: { asset: attributes }

          expect(assigns(:asset).redirect_url).to be_nil
        end
      end
    end
  end

  describe 'PUT update' do
    context 'an existing asset' do
      let(:attributes) { { file: load_fixture_file('asset2.jpg') } }
      let(:asset) { FactoryBot.create(:asset) }

      it 'persists new attributes on existing asset' do
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset)).to be_persisted
        expect(assigns(:asset).file.path).to match(/asset2\.jpg$/)
      end

      it 'responds with success status' do
        put :update, params: { id: asset.id, asset: attributes }

        expect(response).to have_http_status(:success)
      end

      it 'stores access_limited on existing asset' do
        put :update, params: { id: asset.id, asset: attributes.merge(access_limited: ['user-id']) }

        expect(assigns(:asset).access_limited).to eq(['user-id'])
      end

      it 'stores redirect_url on existing asset' do
        redirect_url = 'https://example.com/path/file.ext'
        put :update, params: { id: asset.id, asset: attributes.merge(redirect_url: redirect_url) }

        expect(assigns(:asset).redirect_url).to eq(redirect_url)
      end

      it 'stores blank redirect_url as nil on existing asset' do
        redirect_url = ''
        put :update, params: { id: asset.id, asset: attributes.merge(redirect_url: redirect_url) }

        expect(assigns(:asset).redirect_url).to be_nil
      end

      it 'responds with the details of the existing asset' do
        put :update, params: { id: asset.id, asset: attributes }

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        expect(body['id']).to eq("http://test.host/assets/#{asset.id}")
        expect(body['name']).to eq('asset2.jpg')
        expect(body['content_type']).to eq('image/jpeg')
        expect(body['draft']).to be_falsey
      end

      context 'when attributes include draft status' do
        let(:attributes) { { draft: true, file: load_fixture_file('asset2.jpg') } }

        it 'stores draft status on existing asset' do
          put :update, params: { id: asset.id, asset: attributes }

          expect(assigns(:asset)).to be_draft
        end

        it 'includes the draft status in the response' do
          put :update, params: { id: asset.id, asset: attributes }

          body = JSON.parse(response.body)

          expect(body['draft']).to be_truthy
        end
      end
    end
  end

  describe 'DELETE destroy' do
    context 'an existing asset' do
      let(:asset) { FactoryBot.create(:asset) }

      it 'deletes the asset' do
        delete :destroy, params: { id: asset.id }

        expect(Asset.where(id: asset.id).first).to be_nil
      end

      it 'responds with a success status' do
        delete :destroy, params: { id: asset.id }

        expect(response).to have_http_status(:success)
      end
    end

    context 'no existing asset' do
      it 'responds with not found status' do
        delete :destroy, params: { id: '12345' }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when Asset#destroy fails' do
      let(:asset) { FactoryBot.create(:asset) }
      let(:errors) { ActiveModel::Errors.new(asset) }

      before do
        errors.add(:base, 'Something went wrong')
        allow_any_instance_of(Asset).to receive(:destroy).and_return(false)
        allow_any_instance_of(Asset).to receive(:errors).and_return(errors)
        delete :destroy, params: { id: asset.id }
      end

      it 'responds with unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'includes the errors in the response' do
        expect(response.body).to match(/Something went wrong/)
      end
    end
  end

  describe 'GET show' do
    context 'an asset which exists' do
      let(:asset) { FactoryBot.create(:asset) }

      it 'responds with success status' do
        get :show, params: { id: asset.id }

        expect(response).to be_success
      end

      it 'makes the asset available to the view template' do
        get :show, params: { id: asset.id }

        expect(assigns(:asset)).to be_a(Asset)
        expect(assigns(:asset).id).to eq(asset.id)
      end

      it 'includes the draft status in the response' do
        get :show, params: { id: asset.id }

        body = JSON.parse(response.body)

        expect(body['draft']).to be_falsey
      end

      it 'sets the Cache-Control header max-age to 0' do
        get :show, params: { id: asset.id }

        expect(response.headers['Cache-Control']).to eq('max-age=0, public')
      end
    end

    context 'no existing asset' do
      it 'responds with not found status' do
        get :show, params: { id: 'some-gif-or-other' }

        expect(response).to have_http_status(:not_found)
      end

      it 'responds with not found message' do
        get :show, params: { id: 'some-gif-or-other' }

        body = JSON.parse(response.body)
        expect(body['_response_info']['status']).to eq('not found')
      end
    end

    describe 'POST restore' do
      context 'an asset marked as deleted' do
        let(:asset) { FactoryBot.create(:asset, deleted_at: 10.minutes.ago) }

        before do
          post :restore, params: { id: asset.id }
        end

        it 'responds with success status' do
          expect(response).to be_success
        end

        it 'marks the asset as not deleted' do
          restored_asset = assigns(:asset)
          expect(restored_asset).to be
          expect(restored_asset.deleted_at).to be_nil
        end

        context 'when restoring fails' do
          let(:errors) { ActiveModel::Errors.new(asset) }

          before do
            errors.add(:base, 'Something went wrong')
            allow_any_instance_of(Asset).to receive(:restore).and_return(false)
            allow_any_instance_of(Asset).to receive(:errors).and_return(errors)
            post :restore, params: { id: asset.id }
          end

          it 'responds with unprocessable entity status' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'includes the errors in the response' do
            expect(response.body).to match(/Something went wrong/)
          end
        end
      end
    end
  end
end
