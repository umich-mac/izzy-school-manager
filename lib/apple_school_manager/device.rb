# frozen_string_literal: true

module AppleSchoolManager
  class Device
    attr_accessor :serial_number       # Serial Number; YABBADABA0
    attr_accessor :model_identifier    # Model Identifier; MacBookPro15,2
    attr_accessor :marketing_name      # Marketing Name; MacBook Pro (13-inch, 2018, Four Thunderbolt 3 Ports)
    attr_accessor :assigned_mdm_server # Link to MDMServer object
    attr_accessor :coverages           # Array of Coverage objects
    attr_accessor :product_family      # Product Family; Mac
    attr_accessor :product_type        # Product Type; MacBook Pro
    attr_accessor :status              # Status; active, etc.
    attr_accessor :capacity            # Device Capacity; 256GB, etc.
    attr_accessor :color               # Color; Space Gray, etc.

    def initialize(attributes = {})
      @serial_number = attributes[:serial_number]
      @model_identifier = attributes[:model_identifier]
      @marketing_name = attributes[:marketing_name]
      @assigned_mdm_server = attributes[:assigned_mdm_server]
      @coverages = attributes[:coverages] || []
      @product_family = attributes[:product_family]
      @product_type = attributes[:product_type]
      @status = attributes[:status]
      @capacity = attributes[:capacity]
      @color = attributes[:color]
    end

    # Returns the furthest out end date from all active coverages
    def warranty_expires_on
      active_coverages = @coverages.select(&:active?)
      return nil if active_coverages.empty?

      active_coverages.map(&:end_date).compact.max
    end

    # Returns array of supported macOS versions (e.g., ["Sequoia", "Tahoe"])
    def supported_macos_versions
      MacOSCompatibility.supported_versions(@model_identifier)
    end

    # Returns the latest supported macOS version
    def latest_macos
      MacOSCompatibility.latest_supported(@model_identifier)
    end

    # Check if device supports a specific macOS version
    def supports_macos?(version)
      MacOSCompatibility.supports?(@model_identifier, version)
    end
  end
end
