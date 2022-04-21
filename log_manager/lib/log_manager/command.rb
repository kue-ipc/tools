# frozen_string_literal: true

# = LogManager::Command
# compatible with Ruby 2.0.0
#
# Copyright 2022 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'logger'
require 'optparse'

module LogManager


  class Command
    HELP_MESSAGE = <<-MESSAGE
Log Manager #{VERSION}
Usage: lmg subcommand [options]
Subcommands:
  config ... show config
  clean  ... clean and compress log
  rsync  ... rysnc log from remote
  scp    ... scp log from remote
  help   ... display this messages
    MESSAGE

    def run(argv)
      opt = OptParser.new

      # opt.on('-h')
      opt.parse!(ARGV)



      if argv.empty?
        print HELP_MESSAGE
        return 0
      end

      subcommand = argv[0]
      options = argv[1, argv.size - 1]
      p options

      case subcommand
      when 'config'
      when 'clean'
      when 'rsync'
      when 'scp'
      when 'help'
        print HELP_MESSAGE
        return 0
      else
        warn 'Error: unknown subcommand'
        return 1
      end
    end
  end
end
