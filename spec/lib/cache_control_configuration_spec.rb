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

  describe '#expires_in' do
    context 'when attributes are supplied to constructor' do
      let(:other_options) { { public: true, must_revalidate: true } }
      let(:attributes) { { max_age: 1.hour }.merge(other_options) }
      let(:new_max_age) { 2.hours }
      let(:new_config) { subject.expires_in(new_max_age) }

      it 'returns a new configuration with max_age set to specified value' do
        expect(new_config.max_age).to eq(new_max_age)
      end

      it 'returns a new configuration with same options as original' do
        expect(new_config.options).to eq(other_options)
      end
    end
  end
end
