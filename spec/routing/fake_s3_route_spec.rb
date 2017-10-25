require 'rails_helper'

RSpec.describe 'routes for S3Storage::Fake', type: :routing do
  let(:fake_s3_route) { Rails.application.routes.named_routes.get('fake_s3') }
  let(:rails_env) { double('rails-env') }

  before do
    allow(Rails).to receive(:env).and_return(rails_env)
    allow(rails_env).to receive(:development?).and_return(is_development)
    Rails.application.reload_routes!
  end

  context 'and Rails environment is development' do
    let(:is_development) { true }

    it 'sets up fake_s3 route' do
      expect(fake_s3_route).to be_present
    end
  end

  context 'and Rails environment is not development' do
    let(:is_development) { false }

    it 'does not set up fake_s3 route' do
      expect(fake_s3_route).not_to be_present
    end
  end
end
