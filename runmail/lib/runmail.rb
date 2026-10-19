# frozen_string_literal: true
# shareable_constant_value: literal

# Run And Mail
# v0.2.0
#
# Copyright 2024-2026 Kyoto University of Eductaion
# Released under the MIT License
# https://opensource.org/licenses/MIT
#
# Compitable: Ruby 3.3 or higher

require_relative "runmail/base"

module Runmail
  VERSION = "0.2.0"

  def self.new(...)
    Base.new(...)
  end
end
