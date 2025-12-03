# AppleSchoolManager

Ruby gem for interacting with the Apple School Manager API to manage device inventory, MDM server assignments, warranty coverage, and macOS compatibility.

## Features

- 🔍 Device lookup by serial number
- 📊 CSV export for bulk device reports
- 🍎 macOS compatibility checking (Sequoia, Tahoe, future versions)
- 🛡️ Warranty and AppleCare coverage tracking
- 🔄 Automatic rate limiting and retry logic for API stability
- 💾 Smart caching to reduce API calls
- 📦 MDM server inventory management

## Installation

### From GitHub Packages

This gem is published to GitHub Packages. To install it, you'll need to configure your gem sources:

**For Bundler (in your Gemfile):**

```ruby
source "https://rubygems.pkg.github.com/umich-mac" do
  gem "apple_school_manager"
end
```

Then run:

```bash
bundle config set --global https://rubygems.pkg.github.com/umich-mac USERNAME:TOKEN
bundle install
```

**For direct installation:**

```bash
gem install apple_school_manager --source "https://rubygems.pkg.github.com/umich-mac"
```

**Note:** You'll need a GitHub Personal Access Token with `read:packages` permission. Set up authentication:

```bash
# Configure gem to authenticate with GitHub Packages
bundle config set --global https://rubygems.pkg.github.com/umich-mac USERNAME:TOKEN
```

Replace `USERNAME` with your GitHub username and `TOKEN` with your [Personal Access Token](https://github.com/settings/tokens).

## Usage

### Setup

First, you'll need:
- An Apple School Manager account with API access
- A private key (ES256) for authentication
- Your `key_id` and `client_id` from Apple School Manager

### Command Line Tool

The gem includes a CLI tool called `asm` for quick device lookups:

```bash
# Set up your credentials as environment variables
export ASM_KEY_ID="your-key-id"
export ASM_CLIENT_ID="SCHOOLAPI.your-client-id"
export ASM_PRIVATE_KEY_PATH="./path/to/key.pem"

# Look up one or more devices by serial number
asm lookup 4ABBADABBA
asm lookup 4ABBADABBA DABBAD000 YADDAYADDA

# Export to CSV
asm lookup 4ABBADABBA DABBAD000 YADDAYADDA --csv > devices.csv

# Get help
asm help
```

Example output:
```
4ABBADABBA: FOUND
  Product Family: Mac
  Device Model: MacBook Pro (14-inch, 2023)
  Model Identifier: Mac14,5
  Status: ASSIGNED
  Capacity: 1TB
  Color: SPACE GRAY
  macOS Support: 15, 26
  MDM Server: Production MDM
  Warranty Expires: 2027-06-06
```

CSV output includes all device details in a structured format for easy import into spreadsheets or databases.

### Ruby Library Example

```ruby
require 'apple_school_manager'

# Initialize the client
client = AppleSchoolManager::Client.new(
  key_id: "your-key-id",
  client_id: "SCHOOLAPI.your-client-id",
  private_key_path: "./path/to/key.pem"
)

# Authenticate with Apple
client.authenticate

# Fetch a device by serial number - returns a Device object
# Automatically uses cache for repeat queries
device = client.fetch_device("4ABBADABBA")

if device
  puts device.serial_number           # => "4ABBADABBA"
  puts device.model_identifier        # => "Mac14,5"
  puts device.marketing_name          # => "MacBook Pro (14-inch, 2023)"
  puts device.assigned_mdm_server.name # => "Production MDM"
  puts device.warranty_expires_on     # => 2027-06-06

  # Check macOS compatibility
  puts device.supported_macos_versions # => [15, 26]
  puts device.latest_macos             # => 26
  puts device.supports_macos?(15)      # => true
end

# Or fetch all devices from a specific MDM server
devices = client.fetch_devices_for_server(
  mdm_server_id: "MDMID0MDMID1MDMID2"
)
```

### Working with Coverage Objects

The gem tracks warranty and AppleCare coverage:

```ruby
device = client.fetch_device("4ABBADABBA")

# Access all coverage plans
device.coverages.each do |coverage|
  puts "#{coverage.description}: #{coverage.status}"
  puts "  Expires: #{coverage.end_date}"
  puts "  Renewable: #{coverage.is_renewable}"
  puts "  Payment: #{coverage.payment_type}"
end

# Get warranty expiration (furthest active coverage)
puts device.warranty_expires_on  # => 2027-06-06
```

### macOS Compatibility Checking

Check which macOS versions a device supports:

```ruby
# Using the compatibility helper directly
AppleSchoolManager::MacOSCompatibility.supported_versions("Mac14,5")
# => [15, 26]

AppleSchoolManager::MacOSCompatibility.supports?("Mac14,5", 26)
# => true

AppleSchoolManager::MacOSCompatibility.latest_supported("Mac14,5")
# => 26

# Or via a Device object
device.supported_macos_versions  # => [15, 26]
device.latest_macos              # => 26
device.supports_macos?(15)       # => true
device.supports_macos?("Sequoia") # => true (named versions also work)
```

### Rate Limiting and Retries

The client automatically handles rate limiting:

- Waits 1 second between API calls
- Automatically retries on 429 (rate limit) errors
- Uses exponential backoff (2s, 4s, 8s, 16s, 32s)
- Provides progress feedback during retries
- Configurable for testing: `rate_limit: false`

```ruby
# Production use (rate limiting enabled by default)
client = AppleSchoolManager::Client.new(
  key_id: key_id,
  client_id: client_id,
  private_key_path: key_path
)

# Testing (disable rate limiting for fast tests)
client = AppleSchoolManager::Client.new(
  key_id: key_id,
  client_id: client_id,
  private_key_path: key_path,
  rate_limit: false
)
```

## Architecture

### Models

- **Device** - Represents Apple devices with serial number, model info, MDM assignment, warranty coverage, and macOS compatibility
- **MDMServer** - Represents MDM servers with ID and name
- **Coverage** - Represents warranty/AppleCare coverage plans with status and dates
- **MacOSCompatibility** - Helper class for checking macOS version compatibility

### Client Features

- JWT-based OAuth 2.0 authentication
- Automatic pagination for large result sets
- Smart caching of devices and MDM servers
- Rate limiting with automatic retry on 429 errors
- Streaming output (no data loss on crashes)

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rspec` to run the tests.

### Running Tests

```bash
# Run all tests (119 examples)
bundle exec rspec

# Run with detailed output
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/apple_school_manager/device_spec.rb
bundle exec rspec spec/apple_school_manager/macos_compatibility_spec.rb
```

### Code Style

This gem uses Standard for Ruby style:

```bash
# Check style
bundle exec standardrb

# Auto-fix issues
bundle exec standardrb --fix
```

## Contributing

Bug reports and pull requests are welcome.

## Credits

This gem was developed with assistance from [Claude](https://claude.ai), Anthropic's AI assistant.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
