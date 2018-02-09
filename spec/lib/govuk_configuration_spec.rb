require 'rails_helper'
require 'govuk_configuration'

RSpec.describe GovukConfiguration do
  subject(:config) { described_class.new(env) }

  describe '#app_host' do
    context 'when environment includes GOVUK_APP_NAME & GOVUK_APP_DOMAIN' do
      let(:env) {
        {
          'GOVUK_APP_NAME' => 'asset-manager',
          'GOVUK_APP_DOMAIN' => 'dev.gov.uk'
        }
      }

      it 'returns application host including protocol' do
        expect(config.app_host).to eq('http://asset-manager.dev.gov.uk')
      end
    end

    context 'when environment only includes GOVUK_APP_NAME' do
      let(:env) {
        {
          'GOVUK_APP_NAME' => 'asset-manager'
        }
      }

      it 'returns nil' do
        expect(config.app_host).to be_nil
      end
    end

    context 'when environment only includes GOVUK_APP_DOMAIN' do
      let(:env) {
        {
          'GOVUK_APP_DOMAIN' => 'dev.gov.uk'
        }
      }

      it 'returns nil' do
        expect(config.app_host).to be_nil
      end
    end

    context 'when environment does not include GOVUK_APP_NAME or GOVUK_APP_DOMAIN' do
      let(:env) { {} }

      it 'returns nil' do
        expect(config.app_host).to be_nil
      end
    end
  end

  describe '#clamscan_path' do
    context 'when environment includes an ASSET_MANAGER_CLAMSCAN_PATH value' do
      let(:env) {
        {
          'ASSET_MANAGER_CLAMSCAN_PATH' => 'alternative-path',
        }
      }

      it 'returns environment variable' do
        expect(config.clamscan_path).to eq('alternative-path')
      end
    end

    context 'when environment does not include an ASSET_MANAGER_CLAMSCAN_PATH value' do
      let(:env) { {} }

      it 'returns govuk_clamscan' do
        expect(config.clamscan_path).to eq('govuk_clamscan')
      end
    end
  end

  describe '#draft_assets_host' do
    subject(:config) { described_class.new(env, plek) }

    let(:env) { {} }
    let(:plek) { instance_double('Plek') }

    before do
      allow(plek).to receive(:external_url_for).with('draft-assets')
        .and_return('https://draft-assets.publishing.service.gov.uk')
    end

    it 'returns externally facing draft-assets host' do
      expect(config.draft_assets_host).to eq('draft-assets.publishing.service.gov.uk')
    end
  end
end
