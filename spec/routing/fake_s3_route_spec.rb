require 'rails_helper'

RSpec.describe 'routes for S3Storage::Fake', type: :routing do
  let(:fake_s3_route) { Rails.application.routes.named_routes.get('fake_s3') }
  let(:s3_config) { instance_double(S3Configuration, fake?: s3_fake_enabled) }

  before do
    allow(AssetManager).to receive(:s3).and_return(s3_config)
    Rails.application.reload_routes!
  end

  context 'when fake S3 is enabled' do
    let(:s3_fake_enabled) { true }

    it 'sets up fake_s3 route' do
      expect(fake_s3_route).to be_present
    end
  end

  context 'when fake S3 is not enabled' do
    let(:s3_fake_enabled) { false }

    it 'does not set up fake_s3 route' do
      expect(fake_s3_route).not_to be_present
    end
  end
end
