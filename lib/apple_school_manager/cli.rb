# frozen_string_literal: true

require "json"
require "csv"

module AppleSchoolManager
  class CLI
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class CommandError < Error; end

    COMMANDS = %w[lookup].freeze

    def initialize(args)
      @args = args
      @client = nil
      @csv_output = false
    end

    def run
      if @args.empty? || @args.first == "help"
        print_help
        return
      end

      command = @args.shift
      unless COMMANDS.include?(command)
        raise CommandError, "Unknown command: #{command}. Run 'asm help' for usage."
      end

      send("cmd_#{command}")
    end

    private

    def cmd_lookup
      # Check for --csv flag
      @csv_output = @args.delete("--csv")

      serial_numbers = @args

      if serial_numbers.empty?
        raise CommandError, "No serial numbers provided. Usage: asm lookup SERIAL1 [SERIAL2 ...] [--csv]"
      end

      ensure_client!
      client.authenticate

      # Print CSV header if CSV output
      print_csv_header if @csv_output

      # Fetch and display each device immediately
      serial_numbers.each do |serial|
        device = client.fetch_device(serial)

        if @csv_output
          display_device_csv(serial, device)
        else
          if device.nil?
            puts "#{serial}: NOT FOUND"
          else
            display_device(device)
          end
          puts
        end

        $stdout.flush
      end
    end

    def display_device(device)
      puts "#{device.serial_number}: FOUND"
      puts "  Product Family: #{device.product_family || "N/A"}"
      puts "  Device Model: #{device.marketing_name || "N/A"}"
      puts "  Model Identifier: #{device.model_identifier || "N/A"}"
      puts "  Status: #{device.status || "N/A"}"
      puts "  Capacity: #{device.capacity}" if device.capacity
      puts "  Color: #{device.color}" if device.color && !device.color.empty?

      # Display macOS compatibility
      macos_versions = device.supported_macos_versions
      if macos_versions.any?
        puts "  macOS Support: #{macos_versions.join(", ")}"
      else
        puts "  macOS Support: None (older model)"
      end

      if device.assigned_mdm_server
        server_name = device.assigned_mdm_server.name || device.assigned_mdm_server.id
        puts "  MDM Server: #{server_name}"
      else
        puts "  MDM Server: Unassigned"
      end

      if device.warranty_expires_on
        puts "  Warranty Expires: #{device.warranty_expires_on}"
      end
    end

    def print_csv_header
      puts CSV.generate_line([
        "Serial Number",
        "Found",
        "Product Family",
        "Device Model",
        "Model Identifier",
        "Status",
        "Capacity",
        "Color",
        "macOS Support",
        "MDM Server",
        "Warranty Expires"
      ])
    end

    def display_device_csv(serial, device)
      if device.nil?
        puts CSV.generate_line([serial, "NO", "", "", "", "", "", "", "", "", ""])
      else
        mdm_server_name = if device.assigned_mdm_server
          device.assigned_mdm_server.name || device.assigned_mdm_server.id
        else
          "Unassigned"
        end

        macos_support = device.supported_macos_versions.any? ? device.supported_macos_versions.join(", ") : "None"

        puts CSV.generate_line([
          device.serial_number,
          "YES",
          device.product_family || "",
          device.marketing_name || "",
          device.model_identifier || "",
          device.status || "",
          device.capacity || "",
          device.color || "",
          macos_support,
          mdm_server_name,
          device.warranty_expires_on&.to_s || ""
        ])
      end
    end

    def print_help
      puts "Apple School Manager CLI Tool"
      puts
      puts "Usage: asm COMMAND [OPTIONS]"
      puts
      puts "Commands:"
      puts "  lookup SERIAL1 [SERIAL2 ...] [--csv]   Look up devices by serial number"
      puts "  help                                    Show this help message"
      puts
      puts "Options:"
      puts "  --csv                           Output results in CSV format"
      puts
      puts "Configuration (via environment variables):"
      puts "  ASM_KEY_ID                      Apple School Manager API key ID"
      puts "  ASM_CLIENT_ID                   Apple School Manager client ID"
      puts "  ASM_PRIVATE_KEY_PATH            Path to private key PEM file"
      puts
      puts "Examples:"
      puts "  asm lookup C02YK2ABJG5H"
      puts "  asm lookup SERIAL1 SERIAL2 SERIAL3"
      puts "  asm lookup SERIAL1 SERIAL2 --csv > devices.csv"
    end

    def ensure_client!
      return if @client

      key_id = ENV["ASM_KEY_ID"]
      client_id = ENV["ASM_CLIENT_ID"]
      private_key_path = ENV["ASM_PRIVATE_KEY_PATH"]

      missing = []
      missing << "ASM_KEY_ID" unless key_id
      missing << "ASM_CLIENT_ID" unless client_id
      missing << "ASM_PRIVATE_KEY_PATH" unless private_key_path

      unless missing.empty?
        raise ConfigurationError, "Missing required environment variables: #{missing.join(", ")}"
      end

      unless File.exist?(private_key_path)
        raise ConfigurationError, "Private key file not found: #{private_key_path}"
      end

      @client = Client.new(
        key_id: key_id,
        client_id: client_id,
        private_key_path: private_key_path
      )
    end

    def client
      ensure_client!
      @client
    end
  end
end
