# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ruby gem for interacting with Apple School Manager API to manage device inventory, MDM server assignments, warranty coverage, and macOS compatibility. This gem provides a client library for retrieving and processing information about Apple devices (primarily Macs) enrolled in Apple School Manager.

## Gem Structure

```
lib/
├── apple_school_manager.rb              # Main entry point, loads all components
├── apple_school_manager/
│   ├── version.rb                       # Gem version constant
│   ├── device.rb                        # Device model
│   ├── mdm_server.rb                    # MDMServer model
│   ├── coverage.rb                      # Coverage model (warranty/AppleCare)
│   ├── macos_compatibility.rb           # macOS version compatibility checker
│   ├── client.rb                        # API client with authentication
│   └── cli.rb                           # Command-line interface
bin/
└── asm                                  # Executable CLI tool
spec/
└── apple_school_manager/
    ├── device_spec.rb                   # Device model tests
    ├── mdm_server_spec.rb              # MDMServer model tests
    ├── coverage_spec.rb                 # Coverage model tests
    ├── macos_compatibility_spec.rb      # macOS compatibility tests
    ├── client_spec.rb                   # Client tests with mocked HTTP
    ├── client_fetch_device_spec.rb     # Tests for device lookup methods
    └── cli_spec.rb                      # CLI tests
```

## Core Architecture

**Module Namespace:** All classes are namespaced under `AppleSchoolManager::`

**Main classes:**

- `AppleSchoolManager::Device` (lib/apple_school_manager/device.rb) - Represents Apple devices with attributes:
  - Core: serial_number, model_identifier, marketing_name, product_family, product_type, status, capacity, color
  - Relationships: assigned_mdm_server (MDMServer object), coverages (array of Coverage objects)
  - Computed: warranty_expires_on (Date) - automatically calculated from active coverages
  - macOS Compatibility methods:
    - `#supported_macos_versions` - Returns array of supported macOS version numbers (e.g., [15, 26])
    - `#latest_macos` - Returns the latest supported macOS version number
    - `#supports_macos?(version)` - Checks if device supports a specific version (accepts version number or name like "Sequoia")

- `AppleSchoolManager::MDMServer` (lib/apple_school_manager/mdm_server.rb) - Represents MDM servers with id and name attributes

- `AppleSchoolManager::Coverage` (lib/apple_school_manager/coverage.rb) - Represents warranty/AppleCare coverage with attributes:
  - id, description, status, start_date, end_date, agreement_number, is_renewable, is_canceled, payment_type, contract_cancel_date_time
  - Helper method: `#active?` - returns true if status is "ACTIVE"

- `AppleSchoolManager::MacOSCompatibility` (lib/apple_school_manager/macos_compatibility.rb) - Helper class for checking macOS version compatibility:
  - Class methods for checking device compatibility with macOS versions
  - `::supported_versions(model_identifier)` - Returns array of supported macOS version numbers (e.g., [15, 26])
  - `::supports?(model_identifier, version)` - Checks if model supports specific version (accepts number or name like "Sequoia")
  - `::latest_supported(model_identifier)` - Returns the latest supported macOS version number
  - Maintains compatibility databases for macOS 15 (Sequoia) and macOS 26 (Tahoe)
  - Supports version name lookups: "sequoia" => 15, "tahoe" => 26

- `AppleSchoolManager::Client` (lib/apple_school_manager/client.rb) - API client with methods:
  - `#authenticate` - Obtains access token via JWT-based OAuth 2.0
  - `#fetch_device(serial_number)` - Fetches device by serial number, returns Device instance with hydrated MDMServer and Coverage objects
    - Automatically checks cache first for better performance (O(1) hash lookup)
    - Makes 3 API calls on cache miss: device details, MDM server, warranty coverages
    - Adds fetched device to cache automatically
  - `#fetch_assigned_server(serial_number)` - Fetches the MDM server assigned to a device, returns MDMServer instance (cached by ID)
  - `#fetch_coverages(serial_number)` - Fetches warranty/AppleCare coverage for a device, returns array of Coverage objects
  - `#fetch_devices_for_server(mdm_server_id:)` - Retrieves all devices from an MDM server with automatic pagination (internal batch size: 100)
  - Caching:
    - `@devices` - Hash keyed by serial number for O(1) device lookups
    - `@mdm_servers` - Hash keyed by server ID for O(1) MDM server lookups
  - Rate limiting and retry features:
    - Automatic 1-second delay between API calls (RATE_LIMIT_DELAY)
    - Exponential backoff retry on 429 (rate limit) errors
    - Configurable via `rate_limit: false` parameter (default: true)
    - Up to 5 retries with delays: 2s, 4s, 8s, 16s, 32s (MAX_RETRIES, INITIAL_RETRY_DELAY)

- `AppleSchoolManager::CLI` (lib/apple_school_manager/cli.rb) - Command-line interface with commands:
  - `lookup SERIAL1 [SERIAL2 ...] [--csv]` - Look up one or more devices by serial number
    - Displays all device details including macOS compatibility and warranty expiration
    - Optional `--csv` flag for CSV output with headers
    - Streaming output (results appear immediately as they're fetched)
  - `help` - Display help message with usage examples
  - Configuration via environment variables: ASM_KEY_ID, ASM_CLIENT_ID, ASM_PRIVATE_KEY_PATH

**Authentication Flow:**
The Apple School Manager API requires JWT-based OAuth 2.0 authentication:
1. Client initialized with key_id, client_id, and path to ES256 private key PEM file
2. `#authenticate` generates JWT assertion signed with private key
3. JWT exchanged for access token via POST to https://account.apple.com/auth/oauth2/token
4. Access token used as Bearer token for subsequent API requests to https://api-school.apple.com/v1/

**API Endpoints:**
- Device lookup by serial: `GET /v1/orgDevices/{serialNumber}` - Serial number is the device ID
- Assigned MDM server: `GET /v1/orgDevices/{serialNumber}/assignedServer` - Returns MDM server hash
- Warranty coverage: `GET /v1/orgDevices/{serialNumber}/appleCareCoverage` - Returns array of coverage objects
- MDM server devices: `GET /v1/mdmServers/{id}/relationships/devices?limit={limit}` - Paginated device list

**Device Lookup Flow:**
The `#fetch_device` method checks cache first, then performs three API calls on cache miss to fully hydrate a Device:
1. Check `@devices` hash for existing device with matching serial number (O(1) lookup)
2. If not cached, make API calls:
   - `/v1/orgDevices/{serialNumber}` - Fetch device details
   - `/v1/orgDevices/{serialNumber}/assignedServer` - Fetch assigned MDM server (returns MDMServer instance)
   - `/v1/orgDevices/{serialNumber}/appleCareCoverage` - Fetch warranty coverages (returns array of Coverage objects)
3. Create Device instance and add to `@devices` hash keyed by serial number
- Returns a fully populated Device instance with all relationships
- MDM servers are memoized in `@mdm_servers` hash keyed by server ID (O(1) lookup)
- Subsequent calls for the same serial number return cached device instantly
- Hash-based caches provide O(1) lookups instead of O(n) array searches
- Much more efficient than fetching all devices from all MDM servers

**Warranty Calculation:**
The Device model calculates warranty expiration automatically:
- `Device#warranty_expires_on` filters for active coverages (status == "ACTIVE")
- Returns the furthest out end_date from all active coverages
- Returns nil if no active coverages exist
- This allows consumers to access full coverage details while getting a simple expiration date

**API Pagination:**
The `#fetch_devices_for_server` method handles pagination automatically:
- Uses internal PAGINATION_BATCH_SIZE constant (100 devices per request)
- Follows "links.next" from response until nil
- Returns flattened array of all device data across pages

## Development Commands

**Setup:**
```bash
bundle install                                    # Install all dependencies
```

**Run tests:**
```bash
bundle exec rspec                                 # Run all tests (119 examples)
bundle exec rspec spec/apple_school_manager/device_spec.rb    # Run Device tests
bundle exec rspec spec/apple_school_manager/mdm_server_spec.rb # Run MDMServer tests
bundle exec rspec spec/apple_school_manager/client_spec.rb     # Run Client tests
bundle exec rspec spec/apple_school_manager/cli_spec.rb        # Run CLI tests
bundle exec rspec --format documentation          # Run with detailed output
```

**Use CLI tool:**
```bash
export ASM_KEY_ID="your-key-id"
export ASM_CLIENT_ID="SCHOOLAPI.your-client-id"
export ASM_PRIVATE_KEY_PATH="./development.pem"

bin/asm lookup 4ABBADABBA                         # Look up device by serial
bin/asm lookup 4ABBADABBA SERIAL2                 # Look up multiple devices
bin/asm lookup 4ABBADABBA SERIAL2 --csv > devices.csv # Export to CSV
bin/asm help                                      # Show help
```

**Linting:**
```bash
bundle exec standardrb                            # Check Ruby style
bundle exec standardrb --fix                      # Auto-fix style issues
```

**Build gem:**
```bash
gem build apple_school_manager.gemspec           # Build .gem file
gem install ./apple_school_manager-0.1.0.gem     # Install locally
```

**Using the gem:**
```ruby
require "apple_school_manager"

# Initialize client (rate limiting enabled by default)
client = AppleSchoolManager::Client.new(
  key_id: "your-key-id",
  client_id: "SCHOOLAPI.your-client-id",
  private_key_path: "path/to/key.pem"
)

# For testing, disable rate limiting
client = AppleSchoolManager::Client.new(
  key_id: "your-key-id",
  client_id: "SCHOOLAPI.your-client-id",
  private_key_path: "path/to/key.pem",
  rate_limit: false
)

client.authenticate

# Fetch a single device with full details (automatically cached)
device = client.fetch_device("4ABBADABBA")
puts device.serial_number           # => "4ABBADABBA"
puts device.model_identifier        # => "Mac14,5"
puts device.marketing_name          # => "MacBook Pro (14-inch, 2023)"
puts device.assigned_mdm_server.name # => "Production MDM"
puts device.warranty_expires_on     # => 2026-04-17 (calculated from active coverages)

# Check macOS compatibility
puts device.supported_macos_versions # => [15, 26]
puts device.latest_macos             # => 26
puts device.supports_macos?(15)      # => true
puts device.supports_macos?("Sequoia") # => true

# Access full coverage details
device.coverages.each do |coverage|
  puts "#{coverage.description}: #{coverage.status} (ends #{coverage.end_date})"
end

# Use MacOSCompatibility helper directly
puts AppleSchoolManager::MacOSCompatibility.supported_versions("Mac14,5") # => [15, 26]
puts AppleSchoolManager::MacOSCompatibility.supports?("Mac14,5", 26)      # => true
puts AppleSchoolManager::MacOSCompatibility.latest_supported("Mac14,5")   # => 26

# Fetch all devices from an MDM server
devices = client.fetch_devices_for_server(mdm_server_id: "MDMID0MDMID1MDMID2")

# Subsequent calls for same serial use cache (no API calls)
device = client.fetch_device("4ABBADABBA") # Returns cached device instantly
```

## Dependencies

**Runtime dependencies:**
- `http` (~> 5.3) - HTTP client for API requests
- `jwt` (~> 3.1) - JWT token generation for Apple API authentication

**Development dependencies:**
- `rspec` (~> 3.13) - Testing framework
- `faker` (~> 3.5) - Test data generation
- `standard` (~> 1.52) - Ruby style guide enforcement
- `rake` (~> 13.0) - Task automation

## Testing Approach

Tests follow TDD principles with comprehensive coverage (119 examples):
- **Device tests**: Initialization, attribute accessors, warranty_expires_on calculation, coverage relationships, macOS compatibility methods
- **MDMServer tests**: Initialization, attribute accessors, device integration
- **Coverage tests**: Initialization, active? helper method
- **MacOSCompatibility tests**: Version lookups, compatibility checks, name resolution (Sequoia/Tahoe), edge cases
- **Client tests**: Authentication flow, device lookup, coverage fetching, MDM server fetching, paginated fetching, rate limiting, retry logic with mocked HTTP responses
- **CLI tests**: Command execution, device display, CSV output, macOS support display, configuration validation

## Publishing

The gem is automatically published to GitHub Packages via GitHub Actions.

**GitHub Actions Workflow** (`.github/workflows/publish-gem.yml`):
- Triggers on release publication or manual workflow dispatch
- Runs full test suite before publishing
- Builds the gem
- Publishes to GitHub Packages at `https://rubygems.pkg.github.com/umich-mac`
- Uses `GITHUB_TOKEN` for authentication (automatically provided by GitHub)

**Creating a Release:**
1. Update version in `lib/apple_school_manager/version.rb`
2. Commit the version change: `git commit -am "Bump version to X.Y.Z"`
3. Create and push a tag: `git tag vX.Y.Z && git push && git push --tags`
4. Create a release on GitHub (releases page or `gh release create`)
5. GitHub Action will automatically build and publish the gem

**Manual Trigger:**
You can also manually trigger the publish workflow from the GitHub Actions tab without creating a release.

## Dependency Management

Dependabot is configured to automatically check for dependency updates monthly.

**Dependabot Configuration** (`.github/dependabot.yml`):
- **Ruby gem dependencies**: Checked monthly (first Monday at 9am)
  - Groups all gem updates into a single PR named "ruby-dependencies"
  - Includes minor and patch updates
  - Major version updates are ignored (must be done manually)
  - 7-day cooldown between PRs to avoid PR spam
- **GitHub Actions dependencies**: Checked monthly (first Monday at 9am)
  - Groups all action updates into a single PR named "github-actions"
  - Includes minor and patch updates
  - Major version updates are ignored (must be done manually)
  - 7-day cooldown between PRs to avoid PR spam
- Commit message prefixes: `deps:` for gems, `ci:` for actions

**Reviewing Dependabot PRs:**
- Dependabot waits 7 days between opening new PRs (cooldown period)
- Dependabot will automatically rebase PRs if needed
- PRs include changelog and release notes links
- Test suite runs automatically on all PRs via CI workflow
