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

      it 'returns default application host for Rails app in development' do
        expect(config.app_host).to eq('http://localhost:3000')
      end
    end

    context 'when environment only includes GOVUK_APP_DOMAIN' do
      let(:env) {
        {
          'GOVUK_APP_DOMAIN' => 'dev.gov.uk'
        }
      }

      it 'returns default application host for Rails app in development' do
        expect(config.app_host).to eq('http://localhost:3000')
      end
    end

    context 'when environment does not include GOVUK_APP_NAME or GOVUK_APP_DOMAIN' do
      let(:env) { {} }

      it 'returns default application host for Rails app in development' do
        expect(config.app_host).to eq('http://localhost:3000')
      end
    end
  end
end
