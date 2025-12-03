# frozen_string_literal: true

module AppleSchoolManager
  class MDMServer
    attr_accessor :id    # MDM Server ID
    attr_accessor :name  # Name of the MDM Server

    def initialize(attributes = {})
      @id = attributes[:id]
      @name = attributes[:name]
    end
  end
end
