require 'rails_helper'

RSpec.describe Healthcheck::RedisHealthcheck do
  subject(:healthcheck) { described_class.new }

  context "when redis is available" do
    specify { expect(healthcheck.status).to eq(:ok) }
  end

  context "when redis is not available" do
    before { allow(Sidekiq).to receive(:redis_info).and_return(false) }
    specify { expect(healthcheck.status).to eq(:critical) }
  end
end
