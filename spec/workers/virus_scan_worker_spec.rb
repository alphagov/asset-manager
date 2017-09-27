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
      expect(GovukError).to receive(:notify).
        with(VirusScanner::InfectedFile.new, extra: { error_message: "/path/to/file: Eicar-Test-Signature FOUND", id: asset.id, filename: asset.filename })

      worker.perform(asset.id)
    end
  end
end
