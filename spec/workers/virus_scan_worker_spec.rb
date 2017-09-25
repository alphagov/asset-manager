require 'rails_helper'

RSpec.describe VirusScanWorker do
  let(:worker) { described_class.new }
  let(:asset) { FactoryGirl.create(:asset) }

  it "calls out to the VirusScanner to scan the file" do
    scanner = double("VirusScanner")
    expect(VirusScanner).to receive(:new).with(asset.file.path).and_return(scanner)
    expect(scanner).to receive(:clean?).and_return(true)

    worker.perform(asset.id)
  end

  it "sets the state to clean if the file is clean" do
    allow_any_instance_of(VirusScanner).to receive(:clean?).and_return(true)

    worker.perform(asset.id)

    asset.reload
    expect(asset.state).to eq('clean')
  end

  context "when a virus is found" do
    before do
      allow_any_instance_of(VirusScanner).to receive(:clean?).and_return(false)
      allow_any_instance_of(VirusScanner).to receive(:virus_info).and_return("/path/to/file: Eicar-Test-Signature FOUND")
    end

    it "sets the state to infected if a virus is found" do
      worker.perform(asset.id)

      asset.reload
      expect(asset.state).to eq('infected')
    end

    it "sends an exception notification" do
      expect(Airbrake).to receive(:notify_or_ignore).
        with(VirusScanner::InfectedFile.new, error_message: "/path/to/file: Eicar-Test-Signature FOUND", params: { id: asset.id, filename: asset.filename })

      worker.perform(asset.id)
    end

    context "when there is an error scanning" do
      let(:error) { VirusScanner::Error.new("Boom!") }

      before do
        allow_any_instance_of(VirusScanner).to receive(:clean?).and_raise(error)
      end

      it "does not change the state, and pass through the error if there is an error scanning" do
        expect {
          worker.perform(asset.id)
        }.to raise_error(VirusScanner::Error, "Boom!")

        asset.reload
        expect(asset.state).to eq("unscanned")
      end

      it "sends an exception notification" do
        expect(Airbrake).to receive(:notify_or_ignore).
          with(error, params: { id: asset.id, filename: asset.filename })

        worker.perform(asset.id) rescue VirusScanner::Error
      end
    end
  end
end
