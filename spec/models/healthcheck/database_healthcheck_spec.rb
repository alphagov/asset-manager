require 'rails_helper'

RSpec.describe Healthcheck::DatabaseHealthcheck do
  subject(:healthcheck) { described_class.new }

  context "when the database is connected" do
    specify { expect(healthcheck.status).to eq(:ok) }
  end

  context "when the database is not available" do
    before do
      allow(Asset)
        .to receive_message_chain(:unscoped, :count) # rubocop:disable RSpec/MessageChain
        .and_raise(Mongo::Error::NoServerAvailable.allocate)
    end

    specify { expect(healthcheck.status).to eq(:critical) }
  end
end
