# frozen_string_literal: true

require "spec_helper"

RSpec.describe AppleSchoolManager::MDMServer do
  describe "#initialize" do
    context "with no arguments" do
      it "creates an MDM server with nil attributes" do
        server = described_class.new

        expect(server.id).to be_nil
        expect(server.name).to be_nil
      end
    end

    context "with partial attributes" do
      it "sets provided id and leaves name nil" do
        server = described_class.new(id: "E0FA31D39B7542D5917AFF755F6983D3")

        expect(server.id).to eq("E0FA31D39B7542D5917AFF755F6983D3")
        expect(server.name).to be_nil
      end

      it "sets provided name and leaves id nil" do
        server = described_class.new(name: "Production MDM")

        expect(server.id).to be_nil
        expect(server.name).to eq("Production MDM")
      end
    end

    context "with all attributes" do
      it "sets all attributes correctly" do
        server = described_class.new(
          id: "E0FA31D39B7542D5917AFF755F6983D3",
          name: "University MDM Server"
        )

        expect(server.id).to eq("E0FA31D39B7542D5917AFF755F6983D3")
        expect(server.name).to eq("University MDM Server")
      end
    end
  end

  describe "attribute accessors" do
    let(:server) { described_class.new }

    describe "#id" do
      it "can be set and retrieved" do
        server.id = "ABC123XYZ"
        expect(server.id).to eq("ABC123XYZ")
      end

      it "can be updated" do
        server.id = "FIRST_ID"
        server.id = "SECOND_ID"
        expect(server.id).to eq("SECOND_ID")
      end

      it "handles typical Apple MDM Server ID format" do
        apple_id = "E0FA31D39B7542D5917AFF755F6983D3"
        server.id = apple_id
        expect(server.id).to eq(apple_id)
        expect(server.id.length).to eq(32)
      end
    end

    describe "#name" do
      it "can be set and retrieved" do
        server.name = "Test MDM Server"
        expect(server.name).to eq("Test MDM Server")
      end

      it "can be updated" do
        server.name = "Old Name"
        server.name = "New Name"
        expect(server.name).to eq("New Name")
      end

      it "handles server names with special characters" do
        server.name = "MDM-Server_2023 (Production)"
        expect(server.name).to eq("MDM-Server_2023 (Production)")
      end

      it "can be set to nil" do
        server.name = "Test"
        server.name = nil
        expect(server.name).to be_nil
      end
    end
  end

  describe "real-world MDM server examples" do
    it "correctly represents a production MDM server" do
      server = described_class.new(
        id: "E0FA31D39B7542D5917AFF755F6983D3",
        name: "University Production MDM"
      )

      expect(server.id).to eq("E0FA31D39B7542D5917AFF755F6983D3")
      expect(server.name).to eq("University Production MDM")
    end

    it "correctly represents a staging MDM server" do
      server = described_class.new(
        id: "ABC123DEF456",
        name: "Staging Environment"
      )

      expect(server.id).to eq("ABC123DEF456")
      expect(server.name).to eq("Staging Environment")
    end

    it "can represent multiple MDM servers" do
      server1 = described_class.new(id: "ID001", name: "MDM 1")
      server2 = described_class.new(id: "ID002", name: "MDM 2")

      expect(server1.id).to eq("ID001")
      expect(server2.id).to eq("ID002")
      expect(server1).not_to eq(server2)
    end
  end

  describe "integration with devices" do
    it "can be assigned to a device" do
      server = described_class.new(
        id: "SERVER123",
        name: "Test MDM"
      )
      device = AppleSchoolManager::Device.new(serial_number: "SERIAL123")

      device.assigned_mdm_server = server

      expect(device.assigned_mdm_server).to eq(server)
      expect(device.assigned_mdm_server.id).to eq("SERVER123")
      expect(device.assigned_mdm_server.name).to eq("Test MDM")
    end
  end
end
