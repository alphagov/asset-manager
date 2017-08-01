require 'rails_helper'

RSpec.describe CacheControlConfiguration do
  subject { described_class.new(attributes) }

  describe '#max_age' do
    let(:attributes) { { max_age: 1.hour } }

    it 'returns max_age attribute value' do
      expect(subject.max_age).to eq(1.hour)
    end
  end

  describe '#options' do
    let(:attributes) { { max_age: 1.hour, public: true } }

    it 'returns all attributes and their values except for max_age' do
      expect(subject.options).to eq(public: true)
    end
  end

  describe '#header' do
    context 'when attributes are supplied to constructor' do
      let(:attributes) { { max_age: 1.hour, public: true, must_revalidate: true } }

      it 'returns Cache-Control header value c.f. expires_in' do
        expect(subject.header).to eq('max-age=3600, public, must-revalidate')
      end
    end

    context 'when only max_age attribute is supplied to constructor' do
      let(:attributes) { { max_age: 1.hour } }

      it "returns Cache-Control header value with default visibility" do
        expect(subject.header).to include('private')
      end
    end
  end
end
