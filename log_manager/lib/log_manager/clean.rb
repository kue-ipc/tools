# frozen_string_literal: true

# = LogManager::Clean
# compatible with Ruby 2.0.0
#
# Copyright 2019 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'logger'

require_relative 'common'

module LogManager
  class Clean < Common
    def initialize(**opts)
      super(opts)
    end

    def compress_file(path)
      comperssed = compressed_path(path)
      if FileTest.exist?(comperssed)
        log_info("delete a existed compressed file: #{comperssed}")
        remove_file(comperssed)
      end

      log_info("compress: #{path}")
      cmd = [*compress_cmd, '--', path]
      run_cmd(cmd)
    end

    def compress_and_delete(path = @config.rood_dir)
      check_path(path)
      begin
        unless FileTest.exist?(path)
          log_warn("skip a removed entry: #{path}")
          return
        end

        unless need_check?(path)
          log_info("not covered: #{path}")
          return
        end

        if FileTest.file?(path)
          if need_delete?(path)
            log_info("remove an expired file: #{path}")
            remove_file(path)
          elsif need_compress?(path)
            compress_file(path)
          else
            log_debug("skip a file: #{path}")
          end
        elsif FileTest.directory?(path)
          entries = Dir.entries(path) - %w[. ..]
          entries.each do |e|
            compress_and_delete(File.join(path, e))
          end
          if (Dir.entries(path) - ['.', '..']).empty?
            log_info("remove an empty dir: #{path}")
            remove_dir(path)
          end
        else
          log_info("skip another type: #{path}")
        end
      end
    rescue StandardError => e
      log_error("error occured #{e.class}: #{path}")
      log_error("error message: #{e.message}")
    end
  end
end
