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
end
