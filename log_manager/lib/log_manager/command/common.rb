# frozen_string_literal: true

# = LogManager::Common
# compatible with Ruby 2.0.0
#
# Copyright 2019 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'fileutils'
require 'open3'

require_relative 'config'
require_relative 'error'

module LogManager
  class Common
    def initialize(**opts)
      @config = Config.new(opts[:config_path], opts)
      log_debug('noop mode') if @config.noop
      @name = "#{self.class.name.split('::').last}[#{object_id.to_s(16)}]"
      @now = Time.now
      @delete_before_time = @now - @config.period_retention
      @compress_before_time = @now - @config.period_nocompress
    end

    def log_fatal(msg)
      @config.logger.log(Logger::FATAL, msg, @name)
    end

    def log_error(msg)
      @config.logger.log(Logger::ERROR, msg, @name)
    end

    def log_warn(msg)
      @config.logger.log(Logger::WARN, msg, @name)
    end

    def log_info(msg)
      @config.logger.log(Logger::INFO, msg, @name)
    end

    def log_debug(msg)
      @config.logger.log(Logger::DEBUG, msg, @name)
    end

    def check_path(path)
      return if path.start_with?(@config.root_dir)

      msg = "path must start with #{@config.root_dir}, but: #{path}"
      log_error(msg)
      raise Error, msg
    end

    def need_check?(path)
      name =
        if @config.compress_ext_list.include?(File.extname(path))
          File.basename(path, File.extname(path))
        else
          File.basename(path)
        end

      @config.file_patterns.any? { |ptn| ptn === name } &&
        @config.file_excludes.none? { |ptn| ptn === name }
    end

    def need_compress?(path)
      need_check?(path) &&
        !@config.compress_ext_list.include?(File.extname(path)) &&
        File.stat(path).mtime < @compress_before_time
    end

    def need_delete?(path)
      need_check?(path) &&
        File.stat(path).mtime < @delete_before_time
    end

    def compressed_path(path)
      path + @config.compress_ext
    end

    def compress_cmd
      if @config.compress_cmd.is_a?(String)
        @config.compress_cmd.split
      else
        @config.compress_cmd
      end
    end

    def make_dir(dir)
      check_path(dir)
      if FileTest.directory?(dir)
        log_debug("A directoy is existed, skip to make: #{dir}")
      else
        log_info("Make a directoy: #{dir}")
        FileUtils.mkdir_p(dir, noop: @config.noop)
      end
    end

    def remove_dir(dir)
      check_path(dir)
      if FileTest.directory?(dir)
        log_info("remove a directoy: #{dir}")
        FileUtils.rmdir(dir, noop: @config.noop)
      else
        log_warn("not a directoy, skip to remove: #{dir}")
      end
    end

    def remove_file(file)
      check_path(file)
      if FileTest.file?(file)
        log_info("remove a file: #{file}")
        FileUtils.rm(file, noop: @config.noop)
      else
        log_warn("not a file, skip to remove: #{file}")
      end
    end

    def run_cmd(cmd)
      log_info("run: #{cmd.join(' ')}")
      if @config.noop
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
