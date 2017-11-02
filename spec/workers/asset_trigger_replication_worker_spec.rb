require 'rails_helper'

RSpec::Matchers.define_negated_matcher :exclude, :include

RSpec.describe AssetTriggerReplicationWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:asset) { FactoryGirl.create(:asset) }
  let(:s3_storage) { instance_double(S3Storage) }

  before do
    allow(Services).to receive(:cloud_storage).and_return(s3_storage)
    allow(s3_storage).to receive(:exists?).and_return(exists_on_s3)
  end

  context 'when asset has no corresponding S3 object' do
    let(:exists_on_s3) { false }

    it 'does not re-save S3 object' do
      expect(s3_storage).to receive(:save).never

      worker.perform(asset.id.to_s)
    end
  end

  context 'when asset has corresponding S3 object' do
    let(:exists_on_s3) { true }

    before do
      allow(s3_storage).to receive(:never_replicated?)
        .with(asset).and_return(never_replicated)
    end

    context 'and asset has never been replicated' do
      let(:never_replicated) { true }

      it 're-saves S3 object to trigger replication' do
        expect(s3_storage).to receive(:save).with(asset, force: true)

        worker.perform(asset.id.to_s)
      end
    end

    context 'and asset has been replicated' do
      let(:never_replicated) { false }

      it 'does not re-save S3 object' do
        expect(s3_storage).to receive(:save).never

        worker.perform(asset.id.to_s)
      end
    end
  end
end
