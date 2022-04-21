# frozen_string_literal: true

# = LogManager::Scp
# compatible with Ruby 2.0.0
#
# Copyright 2019 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'time'
require_relative 'common'
require_relative 'error'

module LogManager
  class Scp < Common
    COMPRESS_EXT = '.gz'
    REMOTE_LS = 'LANG=C /bin/ls -l -L --full-time'
    SSH = '/bin/ssh'
    SCP = '/bin/scp'

    def initialize(**opts)
      super(opts)
    end

    def check_remote_path(path)
      unless /\A[\w\-\/.+_]+\z/ =~ path
        raise Error, "Invalid remote path: #{path}"
      end
    end

    def sync(host, src, dst, includes: [/./], excludes: [])
      begin
        check_path(dst)
        make_dir(dst)
        remote_list = get_list_remote(host, src)
        local_list = get_list_local(dst)

        remote_list.keys
          .select { |name| includes.any? { |ptn| ptn =~ name} }
          .each do |name|

          if local_list.key?(name) &&
             remote_list[name] - local_list[name] < 1
            log_debug("skip a file: #{name}")
            next
          end

          compressed_name = compressed_path(name)
          if local_list.key?(compressed_name) &&
             remote_list[name] - local_list[compressed_name] < 1
           log_debug("skip a file (compressed): #{name}")
            next
          end

          log_info("copy: #{name}")
          copy_cmd = [
            SCP,
            '-p',
            '-q',
            "#{host}:#{src}/#{name}",
            "#{dst}/#{name}"
          ]

          unless @noop
            log_debug("run: #{copy_cmd.join(' ')}")
            output, status = Open3.capture2e(*copy_cmd)
            unless output.empty?
              log_warn("copy output: #{output}")
            end
            unless status.exited?
              log_warn("copy abnormal exit: #{status.exitstatus}")
            end
          end
        end
      rescue => e
        log_error("error occured #{e.class}: #{@host}:#{@target_dir}")
        log_error("error message: #{e.message}")
        raise
      end
    end

    def get_list_remote(host, dir)
      check_remote_path(dir)
      log_debug("Get list from remote: #{host}:#{dir}")
      ls_cmd = REMOTE_LS + ' -- ' + dir
      cmd = [SSH, host, ls_cmd]
      stdout, stderr, status = run_cmd(cmd)

      if status.nil?
        # noop mode
        return []
      end

      unless status.success?
        log_error("Command failed, status: #{status.code}")
        raise Error, 'Failed to get remote list'
      end

      Hash[*stdout.each_line
        .reject { |line| line.start_with?('total') }
        .map do |line|
          list = line.split
          time = Time.parse(list[5..7].join(' '))
          name = list[8]
          [name, time]
        end.flatten]
    end

    def get_list_local(dir)
      check_path(dir)
      log_debug("Get list from local: #{dir}")
      Hash[*Dir.entries(dir)
        .reject { |e| ['.', '..'].include?(e) }
        .select { |e| FileTest.file?(File.join(dir, e)) }
        .map do |e|
          time = File.mtime(File.join(dir, e))
          name = e
          [name, time]
        end.flatten]
    end
  end
end
