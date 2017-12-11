require 'rails_helper'
require 'fake_s3_configuration'

RSpec.describe FakeS3Configuration do
  subject(:config) { described_class.new }

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
end
