# frozen_string_literal: true

# = LogManager::Clean
# compatible with Ruby 2.0.0
#
# Copyright 2019 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'logger'

require 'log_manager/command/base'

module LogManager
  module Command
    class Clean < Base
      def self.run(**opts)
        Clean.new(**opts).compress_and_delete
      end

      def initialize(**opts)
        super

        @now = Time.now
        @delete_before_time = @now - @config[:clean][:period_retention]
        @compress_before_time = @now - @config[:clean][:period_nocompress]

        @includes = @config[:clean][:includes]
        @excludes = @config[:clean][:excludes]
      end

      def need_check?(path)
        name =
          if @config[:clean][:compress][:ext_list].include?(File.extname(path))
            File.basename(path, File.extname(path))
          else
            File.basename(path)
          end

        if @includes && @includes.none? { |ptn| File.fnmatch?(ptn, name) }
          return false
        end

        if @excludes && @excludes.any? { |ptn| File.fnmatch?(ptn, name) }
          return false
        end
        
        true
      end

      def need_delete?(path)
        need_check?(path) &&
          File.stat(path).mtime < @delete_before_time
      end

      def need_compress?(path)
        need_check?(path) &&
          !@config[:clean][:compress][:ext_list].include?(File.extname(path)) &&
          File.stat(path).mtime < @compress_before_time
      end

      def compress_cmd
        if @config[:clean][:compress][:cmd].is_a?(String)
          @config[:clean][:compress][:cmd].split
        else
          @config[:clean][:compress][:cmd]
        end
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

      def compress_and_delete(path = @config[:root_dir])
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
            if path != @config[:root_dir] && (Dir.entries(path) - ['.', '..']).empty?
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
        raise
      end
    end
  end
end
