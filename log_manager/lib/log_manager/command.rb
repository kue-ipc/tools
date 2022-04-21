# frozen_string_literal: true

# = LogManager::Command
# compatible with Ruby 2.0.0
#
# Copyright 2022 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'logger'
require 'optparse'

require 'log_manager'
require 'log_manager/command/config'
require 'log_manager/command/clean'
require 'log_manager/command/rsync'
require 'log_manager/command/scp'

module LogManager
  module Command
    HELP_MESSAGE = <<-MESSAGE
Log Manager #{LogManager::VERSION}
Usage: lmg [options] subcommand [subcommand options]
subcommand:
  config      show config yaml
  clean       clean and compress log
  rsync       rysnc log from remote
  scp         scp log from remote
options:
  -c CONFIG   specify config
subcommand options
  -h HOST     specify host
  -n          no operation
    MESSAGE

    def self.run(argv)
      parser = OptionParser.new

      opts = {}
      parser.on('-c CONFIG') { |v| opts[:config_path] = v} 

      subparsers = Hash.new do |h, k|
        $stderr.puts "No such subcommand: #{k}"
        exit 1
      end

      subparsers['config'] = OptionParser.new

      subparsers['clean'] = OptionParser.new
      subparsers['clean'].on('-n') { opts[:noop] = true}

      subparsers['rsync'] = OptionParser.new
      subparsers['rsync'].on('-h HOST') { |v| opts[:host] = v}
      subparsers['rsync'].on('-n') { opts[:noop] = true}

      subparsers['scp'] = OptionParser.new
      subparsers['scp'].on('-h HOST') { |v| opts[:host] = v}
      subparsers['scp'].on('-n') { opts[:noop] = true}
     
      parser.order!(argv)
      if argv.empty?
        puts HELP_MESSAGE
        exit 1
      end

      opts[:subcommand] = argv.shift
      subparsers[opts[:subcommand]].parse!(argv)

      case opts[:subcommand]
      when 'config'
        Command::Config.run(**opts)
      when 'clean'
        Command::Clean.run(**opts)
      when 'rsync'
        Command::Rsync.run(**opts)
      when 'scp'
        Command::Scp.run(**opts)
      end
    end
  end
end
