# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe AppleSchoolManager::Client do
  let(:key_id) { "your-key-id-your-key-id" }
  let(:client_id) { "SCHOOLAPI.client-id-client-id" }
  let(:private_key_file) do
    Tempfile.new("test_key").tap do |f|
      f.write(generate_test_ec_key)
      f.rewind
    end
  end

  after do
    private_key_file.close
    private_key_file.unlink
  end

  def generate_test_ec_key
    # Generate a test EC key for testing
    key = OpenSSL::PKey::EC.generate("prime256v1")
    key.to_pem
  end

  describe "#initialize" do
    it "creates a client with required parameters" do
      client = described_class.new(
        key_id: key_id,
        client_id: client_id,
        private_key_path: private_key_file.path
      )

      expect(client).to be_a(described_class)
    end

    it "initializes with empty mdm_servers array" do
      client = described_class.new(
        key_id: key_id,
        client_id: client_id,
        private_key_path: private_key_file.path
      )

      expect(client.mdm_servers).to eq({})
    end

    it "initializes with empty devices hash" do
      client = described_class.new(
        key_id: key_id,
        client_id: client_id,
        private_key_path: private_key_file.path
      )

      expect(client.devices).to eq({})
    end
  end

  describe "#authenticate" do
    let(:client) do
      described_class.new(
        key_id: key_id,
        client_id: client_id,
        private_key_path: private_key_file.path,
        rate_limit: false
      )
    end

    context "with successful authentication" do
      it "retrieves an access token" do
        response_body = {access_token: "test_access_token_12345"}.to_json
        mock_response = double("HTTP::Response", code: 200, body: response_body)

        allow(HTTP).to receive(:post).and_return(mock_response)

        client.authenticate

        expect(HTTP).to have_received(:post).with(
          "https://account.apple.com/auth/oauth2/token",
          form: hash_including(
            grant_type: "client_credentials",
            client_id: client_id,
            scope: "school.api"
          )
        )
      end

      it "generates a valid JWT assertion" do
        response_body = {access_token: "test_token"}.to_json
        mock_response = double("HTTP::Response", code: 200, body: response_body)

        allow(HTTP).to receive(:post) do |url, options|
          assertion = options[:form][:client_assertion]

          # Verify JWT structure
          expect(assertion).to be_a(String)
          expect(assertion.split(".").length).to eq(3) # JWT has 3 parts

          mock_response
        end

        client.authenticate
      end
    end

    context "with failed authentication" do
      it "raises AuthenticationError on non-200 response" do
        error_body = {error: "invalid_client"}.to_json
        mock_response = double("HTTP::Response", code: 401, body: error_body)

        allow(HTTP).to receive(:post).and_return(mock_response)

        expect {
          client.authenticate
        }.to raise_error(AppleSchoolManager::AuthenticationError, /Failed to authenticate/)
      end

      it "includes response body in error message" do
        error_body = "Unauthorized access"
        mock_response = double("HTTP::Response", code: 401, body: error_body)

        allow(HTTP).to receive(:post).and_return(mock_response)

        expect {
          client.authenticate
        }.to raise_error(AppleSchoolManager::AuthenticationError, /Unauthorized access/)
      end
    end

    context "with invalid private key" do
      it "raises an error when private key file doesn't exist" do
        client = described_class.new(
          key_id: key_id,
          client_id: client_id,
          private_key_path: "/nonexistent/path/key.pem"
        )

        expect {
          client.authenticate
        }.to raise_error(Errno::ENOENT)
      end
    end
  end

  describe "#fetch_device caching" do
    let(:client) do
      described_class.new(
        key_id: key_id,
        client_id: client_id,
        private_key_path: private_key_file.path,
        rate_limit: false
      )
    end

    context "when device exists in cache" do
      it "returns the cached device" do
        device = AppleSchoolManager::Device.new(serial_number: "CACHED123")
        client.devices["CACHED123"] = device

        result = client.fetch_device("CACHED123")

        expect(result).to eq(device)
        expect(result.serial_number).to eq("CACHED123")
      end

      it "finds device among multiple cached devices" do
        device1 = AppleSchoolManager::Device.new(serial_number: "SERIAL001")
        device2 = AppleSchoolManager::Device.new(serial_number: "SERIAL002")
        device3 = AppleSchoolManager::Device.new(serial_number: "SERIAL003")

        client.devices["SERIAL001"] = device1
        client.devices["SERIAL002"] = device2
        client.devices["SERIAL003"] = device3

        result = client.fetch_device("SERIAL002")

        expect(result).to eq(device2)
      end
    end

    context "when device doesn't exist in cache" do
      before do
        # Mock authentication
        auth_response_body = {access_token: "test_token"}.to_json
        auth_mock_response = double("HTTP::Response", code: 200, body: auth_response_body)
        allow(HTTP).to receive(:post).and_return(auth_mock_response)

        # Mock 404 response for device not found
        device_response = double("HTTP::Response", code: 404, body: "Not found")
        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).with("Bearer test_token").and_return(mock_http_auth)
        allow(mock_http_auth).to receive(:get).and_return(device_response)
      end

      it "returns nil" do
        result = client.fetch_device("NOTFOUND")

        expect(result).to be_nil
      end

      it "returns nil when cache is empty" do
        expect(client.devices).to be_empty

        result = client.fetch_device("ANY_SERIAL")

        expect(result).to be_nil
      end
    end
  end

  describe "#fetch_devices_for_server" do
    let(:client) do
      described_class.new(
        key_id: key_id,
        client_id: client_id,
        private_key_path: private_key_file.path,
        rate_limit: false
      )
    end
    let(:mdm_server_id) { "MDMID0MDMID1MDMID2" }

    before do
      # Mock authentication
      auth_response_body = {access_token: "test_token"}.to_json
      auth_mock_response = double("HTTP::Response", code: 200, body: auth_response_body)
      allow(HTTP).to receive(:post).and_return(auth_mock_response)
    end

    context "with successful response" do
      it "fetches devices from a single page" do
        devices_data = {
          data: [
            {id: "device1", type: "device"},
            {id: "device2", type: "device"}
          ],
          links: {}
        }.to_json

        mock_response = double("HTTP::Response", code: 200, body: devices_data)
        mock_http_auth = double("HTTP::Auth")
        allow(mock_http_auth).to receive(:get).and_return(mock_response)
        allow(HTTP).to receive(:auth).with("Bearer test_token").and_return(mock_http_auth)

        result = client.fetch_devices_for_server(mdm_server_id: mdm_server_id)

        expect(result.length).to eq(2)
        expect(result[0]["id"]).to eq("device1")
        expect(result[1]["id"]).to eq("device2")
      end

      it "handles pagination across multiple pages" do
        page1_data = {
          data: [{id: "device1"}],
          links: {next: "https://api-school.apple.com/v1/page2"}
        }.to_json

        page2_data = {
          data: [{id: "device2"}],
          links: {next: "https://api-school.apple.com/v1/page3"}
        }.to_json

        page3_data = {
          data: [{id: "device3"}],
          links: {}
        }.to_json

        mock_http_auth = double("HTTP::Auth")
        allow(HTTP).to receive(:auth).with("Bearer test_token").and_return(mock_http_auth)

        allow(mock_http_auth).to receive(:get) do |url|
          response_data = if url.include?("page2")
            page2_data
          elsif url.include?("page3")
            page3_data
          else
            page1_data
          end
          double("HTTP::Response", code: 200, body: response_data)
        end

        result = client.fetch_devices_for_server(mdm_server_id: mdm_server_id)

        expect(result.length).to eq(3)
        expect(result.map { |d| d["id"] }).to eq(["device1", "device2", "device3"])
      end

      it "authenticates if not already authenticated" do
        devices_data = {
          data: [{id: "device1"}],
          links: {}
        }.to_json

        mock_response = double("HTTP::Response", code: 200, body: devices_data)
        mock_http_auth = double("HTTP::Auth")
        allow(mock_http_auth).to receive(:get).and_return(mock_response)
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)

        expect(HTTP).to receive(:post) # Authentication call

        client.fetch_devices_for_server(mdm_server_id: mdm_server_id)
      end
    end

    context "with failed response" do
      it "raises APIError on non-200 response" do
        error_body = {error: "Not found"}.to_json
        mock_response = double("HTTP::Response", code: 404, body: error_body)
        mock_http_auth = double("HTTP::Auth")
        allow(mock_http_auth).to receive(:get).and_return(mock_response)
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)

        expect {
          client.fetch_devices_for_server(mdm_server_id: mdm_server_id)
        }.to raise_error(AppleSchoolManager::APIError, /Failed to fetch devices/)
      end

      it "includes response body in error message" do
        error_body = "Invalid MDM server ID"
        mock_response = double("HTTP::Response", code: 400, body: error_body)
        mock_http_auth = double("HTTP::Auth")
        allow(mock_http_auth).to receive(:get).and_return(mock_response)
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)

        expect {
          client.fetch_devices_for_server(mdm_server_id: mdm_server_id)
        }.to raise_error(AppleSchoolManager::APIError, /Invalid MDM server ID/)
      end
    end

    context "with empty response" do
      it "returns empty array when no devices" do
        devices_data = {
          data: [],
          links: {}
        }.to_json

        mock_response = double("HTTP::Response", code: 200, body: devices_data)
        mock_http_auth = double("HTTP::Auth")
        allow(mock_http_auth).to receive(:get).and_return(mock_response)
        allow(HTTP).to receive(:auth).and_return(mock_http_auth)

        result = client.fetch_devices_for_server(mdm_server_id: mdm_server_id)

        expect(result).to eq([])
      end
    end
  end
end
