# frozen_string_literal: true

require "jwt"
require "http"
require "json"
require "date"
require "securerandom"

module AppleSchoolManager
  class Client
    attr_reader :mdm_servers, :devices

    PAGINATION_BATCH_SIZE = 100
    RATE_LIMIT_DELAY = 1.0 # seconds between API calls
    MAX_RETRIES = 5
    INITIAL_RETRY_DELAY = 2.0 # seconds

    def initialize(key_id:, client_id:, private_key_path:, rate_limit: true)
      @key_id = key_id
      @client_id = client_id
      @private_key_path = private_key_path
      @mdm_servers = {} # Hash keyed by MDM server ID
      @devices = {} # Hash keyed by device serial number
      @access_token = nil
      @last_request_time = nil
      @rate_limit_enabled = rate_limit
    end

    def authenticate
      pem = File.read(@private_key_path)
      key = OpenSSL::PKey::EC.new(pem)

      headers = {alg: "ES256", kid: @key_id}
      issued = Time.now.to_i - 60
      expires = Time.now.to_i + 180 * 86400
      payload = {
        sub: @client_id,
        iss: @client_id,
        aud: "https://account.apple.com/auth/oauth2/v2/token",
        iat: issued,
        exp: expires,
        jti: SecureRandom.uuid
      }

      assertion = JWT.encode(payload, key, "ES256", headers)

      url = "https://account.apple.com/auth/oauth2/token"
      data = {
        grant_type: "client_credentials",
        client_id: @client_id,
        client_assertion: assertion,
        scope: "school.api",
        client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
      }

      response = HTTP.post(url, form: data)
      raise AuthenticationError, "Failed to authenticate: #{response.body}" unless response.code == 200

      json_body = JSON.parse(response.body)
      @access_token = json_body["access_token"]
    end

    def fetch_device(serial_number)
      # Check cache first
      return @devices[serial_number] if @devices.key?(serial_number)

      authenticate unless @access_token

      # Fetch device by serial number (serial number is the ID)
      url = "https://api-school.apple.com/v1/orgDevices/#{serial_number}"
      response = http_get_with_retry(url)

      # Return nil if device not found (404)
      return nil if response.code == 404

      raise APIError, "Failed to fetch device: #{response.body}" unless response.code == 200

      data = JSON.parse(response.body)
      device_data = data["data"]
      return nil if device_data.nil?

      # Fetch assigned MDM server and coverages if available
      mdm_server = fetch_assigned_server(serial_number)
      coverages = fetch_coverages(serial_number)

      # Extract attributes from API response
      attrs = device_data["attributes"] || {}

      # Create Device instance
      device = Device.new(
        serial_number: device_data["id"],
        model_identifier: attrs["productType"], # e.g., "Mac14,5"
        marketing_name: attrs["deviceModel"], # e.g., "MacBook Pro (14-inch, 2023)"
        assigned_mdm_server: mdm_server,
        coverages: coverages,
        product_family: attrs["productFamily"],
        product_type: attrs["productType"],
        status: attrs["status"],
        capacity: attrs["deviceCapacity"],
        color: attrs["color"]
      )

      # Add to cache
      @devices[serial_number] = device
      device
    end

    def fetch_assigned_server(serial_number)
      authenticate unless @access_token

      url = "https://api-school.apple.com/v1/orgDevices/#{serial_number}/assignedServer"
      response = http_get_with_retry(url)

      # Return nil if no assigned server (404 or empty)
      return nil if response.code == 404

      raise APIError, "Failed to fetch assigned server: #{response.body}" unless response.code == 200

      data = JSON.parse(response.body)
      # The assignedServer endpoint returns a hash with the server data
      server_data = data["data"]
      return nil if server_data.nil?

      # Check if MDMServer already exists in cache
      server_id = server_data["id"]
      return @mdm_servers[server_id] if @mdm_servers.key?(server_id)

      # Create new MDMServer instance and add to cache
      mdm_server = MDMServer.new(
        id: server_id,
        name: server_data.dig("attributes", "serverName")
      )
      @mdm_servers[server_id] = mdm_server
      mdm_server
    end

    def fetch_coverages(serial_number)
      authenticate unless @access_token

      url = "https://api-school.apple.com/v1/orgDevices/#{serial_number}/appleCareCoverage"
      response = http_get_with_retry(url)

      # Return empty array if no coverage data (404 or empty)
      return [] if response.code == 404

      raise APIError, "Failed to fetch warranty coverage: #{response.body}" unless response.code == 200

      data = JSON.parse(response.body)
      coverage_data = data["data"] || []

      # Convert API response to Coverage objects
      coverage_data.map do |c|
        attrs = c["attributes"] || {}
        Coverage.new(
          id: c["id"],
          description: attrs["description"],
          status: attrs["status"],
          start_date: attrs["startDateTime"] ? Date.parse(attrs["startDateTime"]) : nil,
          end_date: attrs["endDateTime"] ? Date.parse(attrs["endDateTime"]) : nil,
          agreement_number: attrs["agreementNumber"],
          is_renewable: attrs["isRenewable"],
          is_canceled: attrs["isCanceled"],
          payment_type: attrs["paymentType"],
          contract_cancel_date_time: attrs["contractCancelDateTime"]
        )
      end
    end

    def fetch_devices_for_server(mdm_server_id:)
      authenticate unless @access_token

      url = "https://api-school.apple.com/v1/mdmServers/#{mdm_server_id}/relationships/devices?limit=#{PAGINATION_BATCH_SIZE}"
      all_devices = []

      until url.nil?
        response = http_get_with_retry(url)
        raise APIError, "Failed to fetch devices: #{response.body}" unless response.code == 200

        data = JSON.parse(response.body)
        all_devices.concat(data["data"])
        url = data.dig("links", "next")
      end

      all_devices
    end

    private

    # Rate limit API calls to avoid 429 errors
    def rate_limit
      return unless @rate_limit_enabled
      return if @last_request_time.nil?

      elapsed = Time.now - @last_request_time
      if elapsed < RATE_LIMIT_DELAY
        sleep(RATE_LIMIT_DELAY - elapsed)
      end
    ensure
      @last_request_time = Time.now
    end

    # Make an HTTP GET request with retry logic for 429 errors
    def http_get_with_retry(url)
      retries = 0

      loop do
        rate_limit
        response = HTTP.auth("Bearer #{@access_token}").get(url)

        # If not rate limited, return the response
        return response if response.code != 429

        # If we've hit max retries, raise an error
        if retries >= MAX_RETRIES
          raise APIError, "Rate limit exceeded after #{MAX_RETRIES} retries: #{response.body}"
        end

        # Calculate exponential backoff delay
        delay = INITIAL_RETRY_DELAY * (2**retries)
        warn "Rate limited (429). Retrying in #{delay} seconds... (attempt #{retries + 1}/#{MAX_RETRIES})"
        sleep(delay)

        retries += 1
      end
    end
  end
end
