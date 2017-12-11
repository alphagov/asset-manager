require 'rails_helper'
require 'fake_s3_configuration'

RSpec.describe FakeS3Configuration do
  subject(:config) { described_class.new(govuk_config) }

  let(:govuk_config) { instance_double(GovukConfiguration) }

  describe '#root' do
    it 'returns directory path to fake S3 storage' do
      expect(config.root).to eq(Rails.root.join('fake-s3'))
    end
  end

  describe '#path_prefix' do
    it 'returns path prefix to fake S3 route' do
      expect(config.path_prefix).to eq('/fake-s3')
    end
  end

  describe '#host' do
    before do
      allow(govuk_config).to receive(:app_host).and_return('http://example.com')
    end

    it 'returns host to be used in fake S3 URLs' do
      expect(config.host).to eq('http://example.com')
    end
  end
end
