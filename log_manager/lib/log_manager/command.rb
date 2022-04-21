# frozen_string_literal: true

# = LogManager::Command
# compatible with Ruby 2.0.0
#
# Copyright 2022 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'logger'

require_relative 'common'

module LogManager
  class Command
    def initialize(**opts)
      super(opts)
    end
  end
end
