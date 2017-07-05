require 'rails_helper'
require 's3_storage'

RSpec.describe S3Storage do
  let(:asset) { FactoryGirl.build(:asset) }

  describe '#save' do
    it 'does nothing' do
      subject.save(asset)
    end
  end
end
