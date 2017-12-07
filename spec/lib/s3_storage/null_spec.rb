require 'rails_helper'

RSpec.describe S3Storage::Null do
  subject(:storage) { described_class.new }

  let(:asset) { FactoryBot.build(:asset) }

  it 'implements all public methods defined on S3Storage' do
    methods = S3Storage.public_instance_methods(false)
    expect(described_class.public_instance_methods(false)).to include(*methods)
  end

  (described_class.public_instance_methods(false) - %i(save)).each do |method|
    it "raises NotConfiguredError exception when #{method} is called" do
      expect {
        storage.send(method, asset)
      }.to raise_error(S3Storage::NotConfiguredError)
    end
  end
end
