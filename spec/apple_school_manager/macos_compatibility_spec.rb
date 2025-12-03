# frozen_string_literal: true

require "spec_helper"

RSpec.describe AppleSchoolManager::MacOSCompatibility do
  describe "VERSION_NAMES" do
    it "maps version names to numbers" do
      expect(described_class::VERSION_NAMES["sequoia"]).to eq(15)
      expect(described_class::VERSION_NAMES["tahoe"]).to eq(26)
    end
  end

  describe ".supported_versions" do
    it "returns both 15 and 26 for Mac15,10" do
      result = described_class.supported_versions("Mac15,10")
      expect(result).to contain_exactly(15, 26)
    end

    it "returns only 15 for MacBookPro15,2" do
      result = described_class.supported_versions("MacBookPro15,2")
      expect(result).to eq([15])
    end

    it "returns only 26 for Mac16,1" do
      result = described_class.supported_versions("Mac16,1")
      expect(result).to eq([26])
    end

    it "returns empty array for unsupported model" do
      result = described_class.supported_versions("iMac14,1")
      expect(result).to eq([])
    end

    it "returns empty array for nil model" do
      result = described_class.supported_versions(nil)
      expect(result).to eq([])
    end

    it "returns empty array for empty string" do
      result = described_class.supported_versions("")
      expect(result).to eq([])
    end
  end

  describe ".supports?" do
    context "checking Sequoia support" do
      it "returns true for Sequoia-supported model" do
        expect(described_class.supports?("MacBookPro15,2", "Sequoia")).to be true
        expect(described_class.supports?("MacBookPro15,2", 15)).to be true
        expect(described_class.supports?("MacBookPro15,2", "15")).to be true
      end

      it "returns false for non-Sequoia model" do
        expect(described_class.supports?("iMac14,1", "Sequoia")).to be false
      end
    end

    context "checking Tahoe support" do
      it "returns true for Tahoe-supported model" do
        expect(described_class.supports?("Mac16,1", "Tahoe")).to be true
        expect(described_class.supports?("Mac16,1", 26)).to be true
        expect(described_class.supports?("Mac16,1", "26")).to be true
      end

      it "returns false for non-Tahoe model" do
        expect(described_class.supports?("MacBookPro15,2", "Tahoe")).to be false
      end
    end

    it "is case-insensitive" do
      expect(described_class.supports?("Mac15,10", "SEQUOIA")).to be true
      expect(described_class.supports?("Mac16,1", "tahoe")).to be true
    end

    it "returns false for unknown version" do
      expect(described_class.supports?("Mac15,10", "Sonoma")).to be false
    end
  end

  describe ".latest_supported" do
    it "returns 26 for models that support both" do
      result = described_class.latest_supported("Mac15,10")
      expect(result).to eq(26)
    end

    it "returns 15 for 15-only models" do
      result = described_class.latest_supported("MacBookPro15,2")
      expect(result).to eq(15)
    end

    it "returns 26 for 26-only models" do
      result = described_class.latest_supported("Mac16,1")
      expect(result).to eq(26)
    end

    it "returns nil for unsupported models" do
      result = described_class.latest_supported("iMac14,1")
      expect(result).to be_nil
    end
  end

  describe "real-world model compatibility" do
    it "correctly identifies M1 MacBook Air support" do
      # M1 MacBook Air supports both 15 and 26
      result = described_class.supported_versions("MacBookAir10,1")
      expect(result).to contain_exactly(15, 26)
    end

    it "correctly identifies 2018 MacBook Pro support" do
      # 2018 13" MacBook Pro supports 15 but not 26
      result = described_class.supported_versions("MacBookPro15,2")
      expect(result).to eq([15])
    end

    it "correctly identifies Mac Studio support" do
      # Mac Studio (M1 Max/Ultra) supports both
      result = described_class.supported_versions("Mac13,1")
      expect(result).to contain_exactly(15, 26)
    end

    it "correctly identifies iMac Pro is 15-only" do
      result = described_class.supported_versions("iMacPro1,1")
      expect(result).to eq([15])
    end
  end
end
