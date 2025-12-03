# frozen_string_literal: true

require "spec_helper"

RSpec.describe AppleSchoolManager::Device do
  describe "#initialize" do
    context "with no arguments" do
      it "creates a device with nil attributes" do
        device = described_class.new

        expect(device.serial_number).to be_nil
        expect(device.model_identifier).to be_nil
        expect(device.marketing_name).to be_nil
        expect(device.assigned_mdm_server).to be_nil
        expect(device.warranty_expires_on).to be_nil
      end
    end

    context "with partial attributes" do
      it "sets provided attributes and leaves others nil" do
        device = described_class.new(
          serial_number: "YABBADABBA00D",
          model_identifier: "MacBookPro15,2"
        )

        expect(device.serial_number).to eq("YABBADABBA00D")
        expect(device.model_identifier).to eq("MacBookPro15,2")
        expect(device.marketing_name).to be_nil
        expect(device.assigned_mdm_server).to be_nil
        expect(device.warranty_expires_on).to be_nil
      end
    end

    context "with all attributes" do
      it "sets all attributes correctly" do
        mdm_server = AppleSchoolManager::MDMServer.new(id: "SERVER123", name: "Test MDM")
        warranty_date = Date.new(2023, 12, 31)
        coverage = AppleSchoolManager::Coverage.new(
          id: "COV123",
          status: "ACTIVE",
          end_date: warranty_date
        )

        device = described_class.new(
          serial_number: "YABBADABBA00D",
          model_identifier: "MacBookPro15,2",
          marketing_name: "MacBook Pro (13-inch, 2018, Four Thunderbolt 3 Ports)",
          assigned_mdm_server: mdm_server,
          coverages: [coverage]
        )

        expect(device.serial_number).to eq("YABBADABBA00D")
        expect(device.model_identifier).to eq("MacBookPro15,2")
        expect(device.marketing_name).to eq("MacBook Pro (13-inch, 2018, Four Thunderbolt 3 Ports)")
        expect(device.assigned_mdm_server).to eq(mdm_server)
        expect(device.coverages).to eq([coverage])
        expect(device.warranty_expires_on).to eq(warranty_date)
      end
    end
  end

  describe "attribute accessors" do
    let(:device) { described_class.new }

    describe "#serial_number" do
      it "can be set and retrieved" do
        device.serial_number = "YABBADABBA00D"
        expect(device.serial_number).to eq("YABBADABBA00D")
      end

      it "can be updated" do
        device.serial_number = "FIRST_SERIAL"
        device.serial_number = "SECOND_SERIAL"
        expect(device.serial_number).to eq("SECOND_SERIAL")
      end
    end

    describe "#model_identifier" do
      it "can be set and retrieved" do
        device.model_identifier = "MacBookAir10,1"
        expect(device.model_identifier).to eq("MacBookAir10,1")
      end
    end

    describe "#marketing_name" do
      it "can be set and retrieved" do
        device.marketing_name = "MacBook Air (M1, 2020)"
        expect(device.marketing_name).to eq("MacBook Air (M1, 2020)")
      end

      it "handles long marketing names" do
        long_name = "MacBook Pro (16-inch, 2021) with Apple M1 Pro chip"
        device.marketing_name = long_name
        expect(device.marketing_name).to eq(long_name)
      end
    end

    describe "#assigned_mdm_server" do
      it "can be set and retrieved" do
        mdm_server = AppleSchoolManager::MDMServer.new(id: "MDM001", name: "Primary MDM")
        device.assigned_mdm_server = mdm_server
        expect(device.assigned_mdm_server).to eq(mdm_server)
      end

      it "can be reassigned to a different MDM server" do
        mdm1 = AppleSchoolManager::MDMServer.new(id: "MDM001", name: "MDM 1")
        mdm2 = AppleSchoolManager::MDMServer.new(id: "MDM002", name: "MDM 2")

        device.assigned_mdm_server = mdm1
        expect(device.assigned_mdm_server).to eq(mdm1)

        device.assigned_mdm_server = mdm2
        expect(device.assigned_mdm_server).to eq(mdm2)
      end

      it "can be set to nil" do
        mdm_server = AppleSchoolManager::MDMServer.new(id: "MDM001", name: "Test")
        device.assigned_mdm_server = mdm_server
        device.assigned_mdm_server = nil
        expect(device.assigned_mdm_server).to be_nil
      end
    end

    describe "#coverages" do
      it "can be set and retrieved" do
        coverage = AppleSchoolManager::Coverage.new(id: "COV001", status: "ACTIVE")
        device.coverages = [coverage]
        expect(device.coverages).to eq([coverage])
      end

      it "can store multiple coverages" do
        cov1 = AppleSchoolManager::Coverage.new(id: "COV001", status: "ACTIVE")
        cov2 = AppleSchoolManager::Coverage.new(id: "COV002", status: "EXPIRED")
        device.coverages = [cov1, cov2]
        expect(device.coverages.length).to eq(2)
      end

      it "defaults to empty array" do
        expect(device.coverages).to eq([])
      end
    end
  end

  describe "#warranty_expires_on" do
    it "returns nil when no coverages" do
      device = described_class.new
      expect(device.warranty_expires_on).to be_nil
    end

    it "returns nil when no active coverages" do
      coverage = AppleSchoolManager::Coverage.new(
        id: "COV001",
        status: "EXPIRED",
        end_date: Date.new(2020, 1, 1)
      )
      device = described_class.new(coverages: [coverage])
      expect(device.warranty_expires_on).to be_nil
    end

    it "returns end date from single active coverage" do
      coverage = AppleSchoolManager::Coverage.new(
        id: "COV001",
        status: "ACTIVE",
        end_date: Date.new(2025, 6, 15)
      )
      device = described_class.new(coverages: [coverage])
      expect(device.warranty_expires_on).to eq(Date.new(2025, 6, 15))
    end

    it "returns furthest out date from multiple active coverages" do
      cov1 = AppleSchoolManager::Coverage.new(
        id: "COV001",
        status: "ACTIVE",
        end_date: Date.new(2025, 2, 2)
      )
      cov2 = AppleSchoolManager::Coverage.new(
        id: "COV002",
        status: "ACTIVE",
        end_date: Date.new(2026, 4, 17)
      )
      device = described_class.new(coverages: [cov1, cov2])
      expect(device.warranty_expires_on).to eq(Date.new(2026, 4, 17))
    end

    it "ignores expired coverages when finding furthest date" do
      cov1 = AppleSchoolManager::Coverage.new(
        id: "COV001",
        status: "ACTIVE",
        end_date: Date.new(2025, 2, 2)
      )
      cov2 = AppleSchoolManager::Coverage.new(
        id: "COV002",
        status: "EXPIRED",
        end_date: Date.new(2027, 1, 1)
      )
      device = described_class.new(coverages: [cov1, cov2])
      expect(device.warranty_expires_on).to eq(Date.new(2025, 2, 2))
    end
  end

  describe "macOS compatibility" do
    describe "#supported_macos_versions" do
      it "returns supported versions for 15-compatible model" do
        device = described_class.new(model_identifier: "MacBookPro15,2")
        expect(device.supported_macos_versions).to eq([15])
      end

      it "returns supported versions for 26-compatible model" do
        device = described_class.new(model_identifier: "Mac16,1")
        expect(device.supported_macos_versions).to eq([26])
      end

      it "returns both versions for models supporting both" do
        device = described_class.new(model_identifier: "Mac15,10")
        expect(device.supported_macos_versions).to contain_exactly(15, 26)
      end

      it "returns empty array for unsupported model" do
        device = described_class.new(model_identifier: "iMac14,1")
        expect(device.supported_macos_versions).to eq([])
      end
    end

    describe "#latest_macos" do
      it "returns 15 for 15-only models" do
        device = described_class.new(model_identifier: "MacBookPro15,2")
        expect(device.latest_macos).to eq(15)
      end

      it "returns 26 for models supporting both" do
        device = described_class.new(model_identifier: "Mac15,10")
        expect(device.latest_macos).to eq(26)
      end

      it "returns nil for unsupported models" do
        device = described_class.new(model_identifier: "iMac14,1")
        expect(device.latest_macos).to be_nil
      end
    end

    describe "#supports_macos?" do
      it "checks 15 support correctly" do
        device = described_class.new(model_identifier: "MacBookPro15,2")
        expect(device.supports_macos?(15)).to be true
        expect(device.supports_macos?(26)).to be false
      end

      it "checks 26 support correctly" do
        device = described_class.new(model_identifier: "Mac16,1")
        expect(device.supports_macos?(15)).to be false
        expect(device.supports_macos?(26)).to be true
      end
    end
  end

  describe "real-world device examples" do
    it "correctly represents a MacBook Pro" do
      device = described_class.new(
        serial_number: "C02YK2ABJG5H",
        model_identifier: "MacBookPro15,2",
        marketing_name: "MacBook Pro (13-inch, 2018, Four Thunderbolt 3 Ports)"
      )

      expect(device.serial_number).to eq("C02YK2ABJG5H")
      expect(device.model_identifier).to eq("MacBookPro15,2")
      expect(device.marketing_name).to include("MacBook Pro")
      expect(device.supported_macos_versions).to eq([15])
    end

    it "correctly represents a MacBook Air" do
      device = described_class.new(
        serial_number: "FVFCM3XLMGNG",
        model_identifier: "MacBookAir10,1",
        marketing_name: "MacBook Air (M1, 2020)"
      )

      expect(device.serial_number).to eq("FVFCM3XLMGNG")
      expect(device.model_identifier).to eq("MacBookAir10,1")
      expect(device.marketing_name).to include("MacBook Air")
      expect(device.supported_macos_versions).to contain_exactly(15, 26)
    end
  end
end
