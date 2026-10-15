# frozen_string_literal: true

# Run And Mail
# v0.1.1
#
# Copyright 2024-2026 Kyoto University of Eductaion
# Released under the MIT License
# https://opensource.org/licenses/MIT
#
# Compitable: Ruby 3.3 or higher

require_relative "runmail/base"

module Runmail
  VERSION = "0.1.1"

  def self.new(...)
    Base.new(...)
  end
end
