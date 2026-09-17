require 'fileutils'
require 'open3'

require 'log_manager/error'

module LogManager
  module Command
    class Base
      # Base is an abstract class
      # implement menhods in concrete class
      # - self.cohmand
      # - run

      def self.run(config, **opts)
        new(config, **opts).run
      end

      attr_reader :result, :errors

      def initialize(config, noop: false, host: nil, **_opts)
        @config = config
        @noop = noop
        log_info('noop mode') if @noop
        @host = host

        @result = nil
        @errors = []
      end

      def root_dir
        @config.root_dir
      end

      def command
        self.class.command
      end

      def command_dig(*args)
        @config[command.intern].dig(*args)
      end

      def err(msg)
        case msg
        when LogManager::Error
          warn msg.message
          log_error("ERROR: #{msg.message}")
          @errors << msg.message
        when Exception
          warn msg.full_message
          log_error("ERROR: #{msg.full_message(highlight: false)}")
          @errors << msg.message
        else
          warn msg
          log_error("ERROR: #{msg}")
          @errors << msg
        end
      end

      def success?
        @result && @errors.empty?
      end

      def done?
        !@result.nil?
      end

      def log_fatal(msg)
        @config.log(Logger::FATAL, msg, command)
      end

      def log_error(msg)
        @config.log(Logger::ERROR, msg, command)
      end

      def log_warn(msg)
        @config.log(Logger::WARN, msg, command)
      end

      def log_info(msg)
        @config.log(Logger::INFO, msg, command)
      end

      def log_debug(msg)
        @config.log(Logger::DEBUG, msg, command)
      end

      def check_path(path)
        return if path.is_a?(String) && path.start_with?(root_dir)

        raise Error, "path must start with #{root_dir}, but: #{path}"
      end

      def make_dir(dir)
        check_path(dir)
        if FileTest.directory?(dir)
          log_debug("a directoy is existed, skip to make: #{dir}")
        else
          log_info("make a directoy: #{dir}")
          FileUtils.mkdir_p(dir, noop: @noop)
        end
      end

      def remove_dir(dir)
        check_path(dir)
        raise Error, "not a directoy: #{dir}" unless FileTest.directory?(dir)

        log_info("remove a directoy: #{dir}")
        FileUtils.rmdir(dir, noop: @noop)
      end

      def remove_file(file)
        check_path(file)
        raise Error, "not a file: #{file}" unless FileTest.file?(file)

        log_info("remove a file: #{file}")
        FileUtils.rm(file, noop: @noop)
      end

      def run_cmd(cmd, noop: @noop)
        log_info("run: #{cmd.join(' ')}")
        if noop
          log_debug('-- noop echo only --')
          cmd = ['echo', *cmd]
        end

        stdout, stderr, status = Open3.capture3(*cmd)

        stdout.each_line.with_index do |line, idx|
          log_debug("--> stdout[#{idx}] : #{line.chomp}")
        end

        stderr.each_line.with_index do |line, idx|
          log_warn("--> stderr[#{idx}] : #{line.chomp}")
        end

        if status.success?
          log_info('==> normal exit')
        else
          log_error("==> abnormal exit code: #{status.exitstatus}")
        end
        [stdout, stderr, status]
      end
    end
  end
end
