# frozen_string_literal: true

require "spec_helper"

RSpec.describe AppleSchoolManager::CLI do
  let(:key_id) { "test-key-id" }
  let(:client_id) { "SCHOOLAPI.test-client-id" }
  let(:private_key_path) { "/tmp/test_key.pem" }

  before do
    ENV["ASM_KEY_ID"] = key_id
    ENV["ASM_CLIENT_ID"] = client_id
    ENV["ASM_PRIVATE_KEY_PATH"] = private_key_path

    # Mock file existence check
    allow(File).to receive(:exist?).with(private_key_path).and_return(true)
  end

  after do
    ENV.delete("ASM_KEY_ID")
    ENV.delete("ASM_CLIENT_ID")
    ENV.delete("ASM_PRIVATE_KEY_PATH")
  end

  describe "#initialize" do
    it "creates a CLI instance with arguments" do
      cli = described_class.new(["lookup", "SERIAL123"])
      expect(cli).to be_a(described_class)
    end
  end

  describe "#run" do
    context "with no arguments" do
      it "prints help" do
        cli = described_class.new([])
        expect { cli.run }.to output(/Apple School Manager CLI Tool/).to_stdout
      end
    end

    context "with help command" do
      it "prints help" do
        cli = described_class.new(["help"])
        expect { cli.run }.to output(/Apple School Manager CLI Tool/).to_stdout
      end
    end

    context "with unknown command" do
      it "raises CommandError" do
        cli = described_class.new(["unknown"])
        expect {
          cli.run
        }.to raise_error(AppleSchoolManager::CLI::CommandError, /Unknown command: unknown/)
      end
    end

    context "with lookup command" do
      it "calls cmd_lookup" do
        cli = described_class.new(["lookup", "SERIAL123"])
        allow(cli).to receive(:cmd_lookup)

        cli.run

        expect(cli).to have_received(:cmd_lookup)
      end
    end
  end

  describe "#cmd_lookup" do
    let(:mock_client) { instance_double(AppleSchoolManager::Client) }

    before do
      allow(AppleSchoolManager::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:authenticate)
      allow(mock_client).to receive(:fetch_device).and_return(nil)
    end

    context "with no serial numbers" do
      it "raises CommandError" do
        cli = described_class.new(["lookup"])

        expect {
          cli.run
        }.to raise_error(AppleSchoolManager::CLI::CommandError, /No serial numbers provided/)
      end
    end

    context "with valid serial numbers" do
      it "authenticates and fetches devices" do
        cli = described_class.new(["lookup", "SERIAL123"])
        capture_stdout { cli.run }
        expect(mock_client).to have_received(:authenticate).once
        expect(mock_client).to have_received(:fetch_device).with("SERIAL123")
      end

      it "searches Apple School Manager" do
        cli = described_class.new(["lookup", "SERIAL123"])
        capture_stdout { cli.run }
        expect(mock_client).to have_received(:fetch_device).once
      end
    end

    context "when device is found" do
      let(:mdm_server) do
        AppleSchoolManager::MDMServer.new(
          id: "MDM001",
          name: "Test MDM Server"
        )
      end

      let(:device) do
        AppleSchoolManager::Device.new(
          serial_number: "SERIAL123",
          model_identifier: "MacBookPro15,2",
          marketing_name: "MacBook Pro (13-inch, 2018)",
          product_family: "Mac",
          product_type: "MacBookPro15,2",
          status: "ASSIGNED",
          color: "Space Gray",
          capacity: "256GB",
          assigned_mdm_server: mdm_server
        )
      end

      before do
        allow(mock_client).to receive(:fetch_device)
          .with("SERIAL123")
          .and_return(device)
      end

      it "displays device information" do
        cli = described_class.new(["lookup", "SERIAL123"])

        output = nil
        expect {
          output = capture_stdout { cli.run }
        }.not_to raise_error

        expect(output).to include("SERIAL123: FOUND")
        expect(output).to include("Device Model: MacBook Pro (13-inch, 2018)")
        expect(output).to include("Model Identifier: MacBookPro15,2")
        expect(output).to include("Status: ASSIGNED")
        expect(output).to include("Color: Space Gray")
        expect(output).to include("MDM Server: Test MDM Server")
      end
    end

    context "when device is not found" do
      it "displays NOT FOUND message" do
        cli = described_class.new(["lookup", "NOTFOUND123"])

        output = capture_stdout { cli.run }

        expect(output).to include("NOTFOUND123: NOT FOUND")
      end
    end

    context "with multiple serial numbers" do
      it "looks up all serial numbers" do
        cli = described_class.new(["lookup", "SERIAL1", "SERIAL2", "SERIAL3"])

        output = capture_stdout { cli.run }

        expect(output).to include("SERIAL1")
        expect(output).to include("SERIAL2")
        expect(output).to include("SERIAL3")
      end
    end

    context "with --csv flag" do
      let(:mdm_server) do
        AppleSchoolManager::MDMServer.new(
          id: "MDM001",
          name: "Test MDM Server"
        )
      end

      let(:device1) do
        AppleSchoolManager::Device.new(
          serial_number: "SERIAL123",
          model_identifier: "MacBookPro15,2",
          marketing_name: "MacBook Pro (13-inch, 2018)",
          product_family: "Mac",
          product_type: "MacBookPro15,2",
          status: "ASSIGNED",
          color: "Space Gray",
          capacity: "256GB",
          assigned_mdm_server: mdm_server
        )
      end

      let(:device2) do
        AppleSchoolManager::Device.new(
          serial_number: "SERIAL456",
          model_identifier: "MacBookAir10,1",
          marketing_name: "MacBook Air (M1, 2020)",
          product_family: "Mac",
          product_type: "MacBookAir10,1",
          status: "ASSIGNED"
        )
      end

      before do
        allow(mock_client).to receive(:fetch_device).with("SERIAL123").and_return(device1)
        allow(mock_client).to receive(:fetch_device).with("SERIAL456").and_return(device2)
        allow(mock_client).to receive(:fetch_device).with("NOTFOUND").and_return(nil)
      end

      it "outputs CSV format with header" do
        cli = described_class.new(["lookup", "SERIAL123", "--csv"])

        output = capture_stdout { cli.run }

        expect(output).to include("Serial Number,Found,Product Family")
        expect(output).to include("SERIAL123,YES,Mac")
      end

      it "includes all device fields in CSV" do
        cli = described_class.new(["lookup", "SERIAL123", "--csv"])

        output = capture_stdout { cli.run }

        expect(output).to include("SERIAL123")
        expect(output).to include("MacBook Pro (13-inch, 2018)")
        expect(output).to include("MacBookPro15,2")
        expect(output).to include("ASSIGNED")
        expect(output).to include("Space Gray")
        expect(output).to include("256GB")
        expect(output).to include("Test MDM Server")
      end

      it "handles multiple devices in CSV format" do
        cli = described_class.new(["lookup", "SERIAL123", "SERIAL456", "--csv"])

        output = capture_stdout { cli.run }

        lines = output.split("\n")
        expect(lines.length).to eq(3) # Header + 2 devices
        expect(lines[1]).to include("SERIAL123")
        expect(lines[2]).to include("SERIAL456")
      end

      it "handles not found devices in CSV format" do
        cli = described_class.new(["lookup", "NOTFOUND", "--csv"])

        output = capture_stdout { cli.run }

        expect(output).to include("NOTFOUND,NO")
      end

      it "accepts --csv flag in any position" do
        cli = described_class.new(["lookup", "--csv", "SERIAL123"])

        output = capture_stdout { cli.run }

        expect(output).to include("Serial Number,Found")
        expect(output).to include("SERIAL123,YES")
      end
    end
  end

  describe "configuration validation" do
    context "when ASM_KEY_ID is missing" do
      before do
        ENV.delete("ASM_KEY_ID")
      end

      it "raises ConfigurationError" do
        cli = described_class.new(["lookup", "SERIAL123"])

        expect {
          cli.run
        }.to raise_error(AppleSchoolManager::CLI::ConfigurationError, /ASM_KEY_ID/)
      end
    end

    context "when ASM_CLIENT_ID is missing" do
      before do
        ENV.delete("ASM_CLIENT_ID")
      end

      it "raises ConfigurationError" do
        cli = described_class.new(["lookup", "SERIAL123"])

        expect {
          cli.run
        }.to raise_error(AppleSchoolManager::CLI::ConfigurationError, /ASM_CLIENT_ID/)
      end
    end

    context "when ASM_PRIVATE_KEY_PATH is missing" do
      before do
        ENV.delete("ASM_PRIVATE_KEY_PATH")
      end

      it "raises ConfigurationError" do
        cli = described_class.new(["lookup", "SERIAL123"])

        expect {
          cli.run
        }.to raise_error(AppleSchoolManager::CLI::ConfigurationError, /ASM_PRIVATE_KEY_PATH/)
      end
    end

    context "when private key file doesn't exist" do
      before do
        allow(File).to receive(:exist?).with(private_key_path).and_return(false)
      end

      it "raises ConfigurationError" do
        cli = described_class.new(["lookup", "SERIAL123"])

        expect {
          cli.run
        }.to raise_error(AppleSchoolManager::CLI::ConfigurationError, /Private key file not found/)
      end
    end
  end

  describe "help output" do
    it "includes all commands" do
      cli = described_class.new(["help"])
      output = capture_stdout { cli.run }

      expect(output).to include("lookup")
      expect(output).to include("help")
    end

    it "includes configuration instructions" do
      cli = described_class.new(["help"])
      output = capture_stdout { cli.run }

      expect(output).to include("ASM_KEY_ID")
      expect(output).to include("ASM_CLIENT_ID")
      expect(output).to include("ASM_PRIVATE_KEY_PATH")
    end

    it "includes usage examples" do
      cli = described_class.new(["help"])
      output = capture_stdout { cli.run }

      expect(output).to include("Examples:")
      expect(output).to include("asm lookup")
    end
  end

  # Helper method to capture stdout
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
