# frozen_string_literal: true

require "date"

module AppleSchoolManager
  class Coverage
    attr_accessor :id                        # Coverage ID
    attr_accessor :description               # Description (e.g., "Limited Warranty", "AppleCare+")
    attr_accessor :status                    # Status (e.g., "ACTIVE", "EXPIRED")
    attr_accessor :start_date                # Start date (Date)
    attr_accessor :end_date                  # End date (Date)
    attr_accessor :agreement_number          # Agreement number (if applicable)
    attr_accessor :is_renewable              # Boolean
    attr_accessor :is_canceled               # Boolean
    attr_accessor :payment_type              # Payment type (e.g., "NONE", "SUBSCRIPTION")
    attr_accessor :contract_cancel_date_time # DateTime when contract was canceled

    def initialize(attributes = {})
      @id = attributes[:id]
      @description = attributes[:description]
      @status = attributes[:status]
      @start_date = attributes[:start_date]
      @end_date = attributes[:end_date]
      @agreement_number = attributes[:agreement_number]
      @is_renewable = attributes[:is_renewable]
      @is_canceled = attributes[:is_canceled]
      @payment_type = attributes[:payment_type]
      @contract_cancel_date_time = attributes[:contract_cancel_date_time]
    end

    def active?
      status == "ACTIVE"
    end
  end
end
