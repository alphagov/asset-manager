require 'rails_helper'

RSpec.describe Healthcheck do
  subject(:healthcheck) { described_class.new(healthchecks) }

  let(:critical) do
    instance_double('Healthcheck::Base', name: :foo, status: :critical, details: {})
  end

  let(:warning) do
    instance_double('Healthcheck::Base', name: :bar, status: :warning, details: { errors: 7 })
  end

  let(:ok) do
    instance_double('Healthcheck::Base', name: :baz, status: :ok, details: { https: true })
  end

  context "when one of the checks is critical" do
    let(:healthchecks) { [warning, critical, ok] }

    specify { expect(healthcheck.status).to eq(:critical) }
  end

  context "when no checks are critical but one is warning" do
    let(:healthchecks) { [ok, ok, warning] }

    specify { expect(healthcheck.status).to eq(:warning) }
  end

  context "when all the checks are ok" do
    let(:healthchecks) { [ok, ok, ok] }

    specify { expect(healthcheck.status).to eq(:ok) }
  end

  describe "#details" do
    let(:healthchecks) { [critical, warning, ok] }
    let(:expected_checks) {
      {
        foo: { status: :critical },
        bar: { status: :warning, errors: 7 },
        baz: { status: :ok, https: true },
      }
    }

    it "returns a hash containing statuses and details for the checks" do
      expect(healthcheck.details).to eq(
        checks: expected_checks,
      )
    end
  end
end
