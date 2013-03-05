require "spec_helper"

describe Asset do
  describe "creating an asset" do
    it "should be valid given a file" do
      a = Asset.new(:file => load_fixture_file("asset.png"))
      a.should be_valid
    end

    it "should not be valid without a file" do
      a = Asset.new(:file => nil)
      a.should_not be_valid
    end

    it "should be persisted" do
      CarrierWave::Mount::Mounter.any_instance.should_receive(:store!)

      a = Asset.new(:file => load_fixture_file("asset.png"))
      a.save

      a.should be_persisted
    end
  end
end
