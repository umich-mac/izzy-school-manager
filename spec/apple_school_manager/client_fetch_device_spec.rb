# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe AppleSchoolManager::Client, "#fetch_device" do
  let(:key_id) { "test-key-id" }
  let(:client_id) { "SCHOOLAPI.test-client-id" }
  let(:private_key_file) do
    Tempfile.new("test_key").tap do |f|
      key = OpenSSL::PKey::EC.generate("prime256v1")
      f.write(key.to_pem)
      f.rewind
    end
  end
  let(:client) do
    described_class.new(
      key_id: key_id,
      client_id: client_id,
      private_key_path: private_key_file.path,
      rate_limit: false
    )
  end

  after do
    private_key_file.close
    private_key_file.unlink
  end

  before do
    # Mock authentication
    auth_response_body = {access_token: "test_token"}.to_json
    auth_mock_response = double("HTTP::Response", code: 200, body: auth_response_body)
    allow(HTTP).to receive(:post).and_return(auth_mock_response)
  end

  describe "#fetch_device" do
    context "when device exists" do
      let(:device_data) do
        {
          "data" => {
            "id" => "SERIAL123",
            "type" => "orgDevices",
            "attributes" => {
              "deviceModel" => "MacBook Pro (14-inch, 2023)",
              "productType" => "Mac14,5",
              "productFamily" => "Mac",
              "status" => "ASSIGNED"
            }
          }
        }.to_json
      end

      let(:mdm_server_data) do
        {
          "data" => {
            "id" => "MDM001",
            "type" => "mdmServers",
            "attributes" => {
              "serverName" => "Test MDM"
            }
          }
        }.to_json
      end

      let(:warranty_data) do
        {
          "data" => [
            {
              "type" => "appleCareCoverage",
              "id" => "SERIAL123",
              "attributes" => {
                "startDateTime" => "2025-02-02T00:00:00Z",
                "endDateTime" => "2026-02-02T00:00:00Z",
                "status" => "ACTIVE",
                "description" => "Limited Warranty"
              }
            }
          ]
        }.to_json
      end

      before do
        device_response = double("HTTP::Response", code: 200, body: device_data)
        mdm_response = double("HTTP::Response", code: 200, body: mdm_server_data)
        warranty_response = double("HTTP::Response", code: 200, body: warranty_data)

        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).with("Bearer test_token").and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get) do |url|
          if url.include?("assignedServer")
            mdm_response
          elsif url.include?("appleCareCoverage")
            warranty_response
          else
            device_response
          end
        end
      end

      it "returns a Device instance with MDM server and coverages" do
        result = client.fetch_device("SERIAL123")

        expect(result).to be_a(AppleSchoolManager::Device)
        expect(result.serial_number).to eq("SERIAL123")
        expect(result.model_identifier).to eq("Mac14,5")
        expect(result.marketing_name).to eq("MacBook Pro (14-inch, 2023)")
        expect(result.product_family).to eq("Mac")
        expect(result.status).to eq("ASSIGNED")
        expect(result.assigned_mdm_server).to be_a(AppleSchoolManager::MDMServer)
        expect(result.assigned_mdm_server.id).to eq("MDM001")
        expect(result.assigned_mdm_server.name).to eq("Test MDM")
        expect(result.coverages).to be_an(Array)
        expect(result.coverages.first).to be_a(AppleSchoolManager::Coverage)
        expect(result.warranty_expires_on).to eq(Date.new(2026, 2, 2))
        expect(result.supported_macos_versions).to contain_exactly(15, 26)
      end

      it "calls the correct API endpoints" do
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(
          double("HTTP::Response", code: 200, body: device_data),
          double("HTTP::Response", code: 200, body: mdm_server_data),
          double("HTTP::Response", code: 200, body: warranty_data)
        )

        client.fetch_device("SERIAL123")

        expect(mock_http_auth).to have_received(:get).with("https://api-school.apple.com/v1/orgDevices/SERIAL123")
        expect(mock_http_auth).to have_received(:get).with("https://api-school.apple.com/v1/orgDevices/SERIAL123/assignedServer")
        expect(mock_http_auth).to have_received(:get).with("https://api-school.apple.com/v1/orgDevices/SERIAL123/appleCareCoverage")
      end
    end

    context "when device does not exist" do
      before do
        device_response = double("HTTP::Response", code: 404, body: "Not found")
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(device_response)
      end

      it "returns nil" do
        result = client.fetch_device("NOTFOUND")

        expect(result).to be_nil
      end
    end

    context "with API error" do
      before do
        device_response = double("HTTP::Response", code: 500, body: "Internal server error")
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(device_response)
      end

      it "raises APIError" do
        expect {
          client.fetch_device("SERIAL123")
        }.to raise_error(AppleSchoolManager::APIError, /Failed to fetch device/)
      end
    end
  end

  describe "#fetch_coverages" do
    context "when warranty coverage exists" do
      let(:warranty_data) do
        {
          "data" => [
            {
              "type" => "appleCareCoverage",
              "id" => "SERIAL123",
              "attributes" => {
                "startDateTime" => "2025-02-02T00:00:00Z",
                "endDateTime" => "2026-02-02T00:00:00Z",
                "status" => "ACTIVE",
                "description" => "Limited Warranty",
                "agreementNumber" => nil,
                "isRenewable" => false,
                "isCanceled" => false,
                "paymentType" => "NONE",
                "contractCancelDateTime" => nil
              }
            },
            {
              "type" => "appleCareCoverage",
              "id" => "0000000001",
              "attributes" => {
                "startDateTime" => "2025-04-17T00:00:00Z",
                "endDateTime" => "2026-04-17T00:00:00Z",
                "status" => "ACTIVE",
                "description" => "AppleCare+",
                "agreementNumber" => "0000000001",
                "isRenewable" => true,
                "isCanceled" => false,
                "paymentType" => "SUBSCRIPTION",
                "contractCancelDateTime" => nil
              }
            }
          ]
        }.to_json
      end

      before do
        warranty_response = double("HTTP::Response", code: 200, body: warranty_data)
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(warranty_response)
      end

      it "returns an array of Coverage objects" do
        result = client.fetch_coverages("SERIAL123")

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first).to be_a(AppleSchoolManager::Coverage)
        expect(result.first.id).to eq("SERIAL123")
        expect(result.first.description).to eq("Limited Warranty")
        expect(result.first.status).to eq("ACTIVE")
        expect(result.first.end_date).to eq(Date.new(2026, 2, 2))
        expect(result.last.id).to eq("0000000001")
        expect(result.last.description).to eq("AppleCare+")
        expect(result.last.end_date).to eq(Date.new(2026, 4, 17))
      end
    end

    context "when warranty coverage has inactive coverages" do
      let(:warranty_data) do
        {
          "data" => [
            {
              "type" => "appleCareCoverage",
              "id" => "SERIAL123",
              "attributes" => {
                "startDateTime" => "2025-02-02T00:00:00Z",
                "endDateTime" => "2026-02-02T00:00:00Z",
                "status" => "ACTIVE",
                "description" => "Limited Warranty"
              }
            },
            {
              "type" => "appleCareCoverage",
              "id" => "0000000002",
              "attributes" => {
                "startDateTime" => "2024-01-01T00:00:00Z",
                "endDateTime" => "2025-01-01T00:00:00Z",
                "status" => "EXPIRED",
                "description" => "Old Coverage"
              }
            }
          ]
        }.to_json
      end

      before do
        warranty_response = double("HTTP::Response", code: 200, body: warranty_data)
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(warranty_response)
      end

      it "returns all coverages including inactive" do
        result = client.fetch_coverages("SERIAL123")

        expect(result.length).to eq(2)
        expect(result.first.status).to eq("ACTIVE")
        expect(result.last.status).to eq("EXPIRED")
      end
    end

    context "when no warranty coverage exists" do
      before do
        warranty_response = double("HTTP::Response", code: 404, body: "Not found")
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(warranty_response)
      end

      it "returns empty array" do
        result = client.fetch_coverages("SERIAL123")

        expect(result).to eq([])
      end
    end

    context "when no active coverages exist" do
      let(:warranty_data) do
        {
          "data" => [
            {
              "type" => "appleCareCoverage",
              "id" => "0000000002",
              "attributes" => {
                "startDateTime" => "2024-01-01T00:00:00Z",
                "endDateTime" => "2025-01-01T00:00:00Z",
                "status" => "EXPIRED",
                "description" => "Old Coverage"
              }
            }
          ]
        }.to_json
      end

      before do
        warranty_response = double("HTTP::Response", code: 200, body: warranty_data)
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(warranty_response)
      end

      it "returns expired coverage" do
        result = client.fetch_coverages("SERIAL123")

        expect(result.length).to eq(1)
        expect(result.first.status).to eq("EXPIRED")
      end
    end

    context "with API error" do
      before do
        warranty_response = double("HTTP::Response", code: 500, body: "Internal server error")
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(warranty_response)
      end

      it "raises APIError" do
        expect {
          client.fetch_coverages("SERIAL123")
        }.to raise_error(AppleSchoolManager::APIError, /Failed to fetch warranty coverage/)
      end
    end
  end

  describe "#fetch_assigned_server" do
    context "when assigned server exists" do
      let(:mdm_server_data) do
        {
          "data" => {
            "id" => "MDM001",
            "type" => "mdmServers",
            "attributes" => {
              "serverName" => "Test MDM Server"
            }
          }
        }.to_json
      end

      before do
        mdm_response = double("HTTP::Response", code: 200, body: mdm_server_data)
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(mdm_response)
      end

      it "returns an MDMServer instance" do
        result = client.fetch_assigned_server("SERIAL123")

        expect(result).to be_a(AppleSchoolManager::MDMServer)
        expect(result.id).to eq("MDM001")
        expect(result.name).to eq("Test MDM Server")
      end
    end

    context "when no assigned server" do
      before do
        mdm_response = double("HTTP::Response", code: 404, body: "Not found")
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(mdm_response)
      end

      it "returns nil" do
        result = client.fetch_assigned_server("SERIAL123")

        expect(result).to be_nil
      end
    end

    context "with API error" do
      before do
        mdm_response = double("HTTP::Response", code: 500, body: "Internal server error")
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(mdm_response)
      end

      it "raises APIError" do
        expect {
          client.fetch_assigned_server("SERIAL123")
        }.to raise_error(AppleSchoolManager::APIError, /Failed to fetch assigned server/)
      end
    end
  end
end
