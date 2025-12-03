# frozen_string_literal: true

require_relative "apple_school_manager/version"
require_relative "apple_school_manager/device"
require_relative "apple_school_manager/mdm_server"
require_relative "apple_school_manager/coverage"
require_relative "apple_school_manager/macos_compatibility"
require_relative "apple_school_manager/client"
require_relative "apple_school_manager/cli"

module AppleSchoolManager
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class APIError < Error; end
end
