require 'rails_helper'

RSpec.describe CacheControlMiddleware do
  let(:headers) { {} }
  let(:app) { ->(_env) { [200, headers, ['OK']] } }

  subject { described_class.new(app) }

  context 'when Rack::ETag adds Cache-Control response header' do
    before do
      headers['Cache-Control'] = 'no-cache'
    end

    context 'when proxying asset requests to S3 via Nginx' do
      before do
        headers['X-Accel-ETag'] = %{"599ef674-1d"}
      end

      it 'removes Cache-Control response header' do
        _status, headers, _body = subject.call([])

        expect(headers['Cache-Control']).not_to be_present
      end
    end

    context 'when not proxying asset requests to S3 via Nginx' do
      it 'does not remove Cache-Control response header' do
        _status, headers, _body = subject.call([])

        expect(headers['Cache-Control']).to eq('no-cache')
      end
    end
  end
end
