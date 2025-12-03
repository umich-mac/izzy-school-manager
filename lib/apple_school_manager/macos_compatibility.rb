# frozen_string_literal: true

module AppleSchoolManager
  class MacOSCompatibility
    # Version name to number mapping
    VERSION_NAMES = {
      "sequoia" => 15,
      "tahoe" => 26
    }.freeze

    # macOS 15 Sequoia compatible models
    MACOS_15_SEQUOIA_MODELS = %w[
      iMac19,1
      iMac19,2
      iMac20,1
      iMac20,2
      iMac21,1
      iMac21,2
      iMacPro1,1
      Mac13,1
      Mac13,2
      Mac14,10
      Mac14,12
      Mac14,13
      Mac14,14
      Mac14,15
      Mac14,2
      Mac14,3
      Mac14,5
      Mac14,6
      Mac14,7
      Mac14,8
      Mac14,9
      Mac15,10
      Mac15,11
      Mac15,12
      Mac15,13
      Mac15,3
      Mac15,4
      Mac15,5
      Mac15,6
      Mac15,7
      Mac15,8
      Mac15,9
      MacBookAir10,1
      MacBookAir9,1
      MacBookPro15,1
      MacBookPro15,2
      MacBookPro15,3
      MacBookPro15,4
      MacBookPro16,1
      MacBookPro16,2
      MacBookPro16,3
      MacBookPro16,4
      MacBookPro17,1
      MacBookPro18,1
      MacBookPro18,2
      MacBookPro18,3
      MacBookPro18,4
      Macmini8,1
      Macmini9,1
      MacPro7,1
    ].freeze

    # macOS 26 Tahoe compatible models
    MACOS_26_TAHOE_MODELS = %w[
      iMac20,1
      iMac20,2
      iMac21,1
      iMac21,2
      Mac13,1
      Mac13,2
      Mac14,10
      Mac14,12
      Mac14,13
      Mac14,14
      Mac14,15
      Mac14,2
      Mac14,3
      Mac14,5
      Mac14,6
      Mac14,7
      Mac14,8
      Mac14,9
      Mac15,10
      Mac15,11
      Mac15,12
      Mac15,13
      Mac15,14
      Mac15,3
      Mac15,4
      Mac15,5
      Mac15,6
      Mac15,7
      Mac15,8
      Mac15,9
      Mac16,1
      Mac16,10
      Mac16,11
      Mac16,12
      Mac16,13
      Mac16,2
      Mac16,3
      Mac16,5
      Mac16,6
      Mac16,7
      Mac16,8
      Mac16,9
      MacBookAir10,1
      MacBookPro16,1
      MacBookPro16,2
      MacBookPro16,4
      MacBookPro17,1
      MacBookPro18,1
      MacBookPro18,2
      MacBookPro18,3
      MacBookPro18,4
      Macmini9,1
      MacPro7,1
    ].freeze

    # Check which macOS versions a model supports
    # Returns an array of supported version numbers (e.g., [15, 26])
    def self.supported_versions(model_identifier)
      return [] if model_identifier.nil? || model_identifier.empty?

      versions = []
      versions << 15 if MACOS_15_SEQUOIA_MODELS.include?(model_identifier)
      versions << 26 if MACOS_26_TAHOE_MODELS.include?(model_identifier)
      versions
    end

    # Check if a model supports a specific macOS version
    def self.supports?(model_identifier, version)
      supported = supported_versions(model_identifier)

      # Try to look up version name first
      version_num = if version.is_a?(String)
        VERSION_NAMES[version.downcase] || version.to_i
      else
        version
      end

      # Check if the numeric version is in the supported list
      supported.include?(version_num)
    end

    # Get the latest supported macOS version for a model
    def self.latest_supported(model_identifier)
      versions = supported_versions(model_identifier)
      return nil if versions.empty?

      # Return the highest version number
      versions.max
    end
  end
end
