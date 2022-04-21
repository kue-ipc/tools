# frozen_string_literal: true

# = LogManager::Common
# compatible with Ruby 2.0.0
#
# Copyright 2019 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'fileutils'
require 'open3'

require 'log_manager/command/config'
require 'log_manager/error'

module LogManager
  module Command
    class Base < Config
      def initialize(noop: false, **opts)
        super

        @noop = nopp
        log_debug('noop mode') if @noop
      end

      def check_path(path)
        return if path.start_with?(@config[:root_dir])

        msg = "path must start with #{@config[:root_dir]}, but: #{path}"
        log_error(msg)
        raise Error, msg
      end

      def make_dir(dir)
        check_path(dir)
        if FileTest.directory?(dir)
          log_debug("A directoy is existed, skip to make: #{dir}")
        else
          log_info("Make a directoy: #{dir}")
          FileUtils.mkdir_p(dir, noop: @noop)
        end
      end

      def remove_dir(dir)
        check_path(dir)
        if FileTest.directory?(dir)
          log_info("remove a directoy: #{dir}")
          FileUtils.rmdir(dir, noop: @noop)
        else
          log_warn("not a directoy, skip to remove: #{dir}")
        end
      end

      def remove_file(file)
        check_path(file)
        if FileTest.file?(file)
          log_info("remove a file: #{file}")
          FileUtils.rm(file, noop: @noop)
        else
          log_warn("not a file, skip to remove: #{file}")
        end
      end

      def run_cmd(cmd)
        log_info("run: #{cmd.join(' ')}")
        if @noop
          log_debug('-- noop --')
          return '', '', nil
        end

        stdout, stderr, status = Open3.capture3(*cmd)

        unless stdout.empty?
          stdout.each_line.with_index do |line, idx|
            log_debug("--> stdout[#{idx}] : #{line.chomp}")
          end
        end

        unless stderr.empty?
          stderr.each_line.with_index do |line, idx|
            log_debug("--> stderr[#{idx}] : #{line.chomp}")
          end
        end

        if status.success?
          log_info('==> normal exit')
        else
          log_warn("==> abnormal exit code: #{status.exitstatus}")
        end
        [stdout, stderr, status]
      end
    end
  end
end
