# frozen_string_literal: true

# = LogManager::Scp
# compatible with Ruby 2.0.0
#
# Copyright 2019 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'time'
require 'log_manager/command/base'
require 'log_manager/error'

module LogManager
  module Command
    class Scp < Base
      REMOTE_LS = 'LANG=C ls -l -a -L --full-time'

      FTYPE_NAMES = {
        'b' => 'blockSpecial',
        'c' => 'characterSpecial',
        'd' => 'directory',
        'l' => 'link',
        's' => 'socket',
        'p' => 'fifo',
        '-' => 'file',
      }

      def self.run(**opts)
        Scp.new(**opts).all_sync
      end

      def initialize(host: nil, **opts)
        super
        @host = host
        @save_dir = File.expand_path(@config[:scp][:save_dir], @config[:root_dir])
        @ssh_cmd = @config[:scp][:ssh_cmd]
        @scp_cmd = @config[:scp][:scp_cmd]
      end

      def check_remote_path(path)
        unless /\A[\w\-\/.+_]+\z/ =~ path
          raise Error, "Invalid remote path: #{path}"
        end
      end

      def all_sync
        @config[:scp][:hosts].each do |host|
          next if @host && @host != host[:name]
          
          host_sync(**host)
        end
      end

      def host_sync(name: nil, host: nil, user: 'root', targets: [])
        if name.nil?
          log_error('no "name" in host')
          return
        end

        log_info("sync host: #{name}")

        if host.nil?
          log_error('no "host" in host')
          return
        end
        
        remote = "#{user}@#{host}"
        host_save_dir = File.join(@save_dir, name)

        targets.each do |target|
          target_sync(remote, host_save_dir, **target)
        end
      end

      def target_sync(remote, host_save_dir, name: nil, dir: nil, **opts)
        if name.nil?
          log_error('no "name" in target')
          return
        end

        log_info("sync target: #{name}")

        if dir.nil?
          log_error('no "dir" in target')
          return
        end

        target_save_dir = File.join(host_save_dir, name)

        sync(
          remote,
          dir,
          target_save_dir,
          **opts
        )
      end

      def sync(remote, src, dst, includes: nil, excludes: nil)
        begin
          check_path(dst)
          make_dir(dst)
          remote_list = get_list_remote(remote, src)
          local_list = get_list_local(dst)

          local_dict = {}
          local_list.each do |local_file|
            local_dict[local_file[:name]] = local_file
          end

          remote_list.each do |remote_file|
            next unless remote_file[:ftype] == 'file'

            name = remote_file[:name]
            if includes &&
               includes.none?  { |ptn| File.fnmatch?(ptn, name) }
              next
            end
            if excludes &&
               excludes.any?  { |ptn| File.fnmatch?(ptn, name) }
              next
            end

            if (local_file = local_dict[name])
              if local_file[:ftype] != 'file'
                log_warn("duplicate with other than file: #{name}")
                next
              elsif remote_file[:mtime] <= local_file[:mtime]
                log_debug("skip a file: #{name}")
                next
              end
            end

            compressed_name = compressed_path(name)
            if (local_file = local_dict[compressed_name])
              if local_file[:ftype] != 'file'
                log_warn("duplicate with other than file (compressed): #{name}")
                next
              elsif remote_file[:mtime] <= local_file[:mtime]
                log_debug("skip a file (compressed): #{name}")
                next
              end
            end

            log_info("copy: #{name}")
            cmd = [
              @scp_cmd,
              '-p',
              '-q',
              "#{remote}:#{src}/#{name}",
              "#{dst}/#{name}"
            ]
            run_cmd(cmd)
          end
        rescue => e
          log_error("error message: #{e.message}")
          raise
        end
      end

      def get_list_remote(remote, dir)
        check_remote_path(dir)
        log_debug("get list from remote: #{remote}:#{dir}")
        ls_cmd = REMOTE_LS + ' -- ' + dir
        cmd = [@ssh_cmd, remote, ls_cmd]
        stdout, stderr, status = run_cmd(cmd)

        return [] if status.nil? # for noop mode

        unless status.success?
          log_error("command failed, status: #{status.to_i}")
          return []
        end

        stdout.lines
          .drop(1) # drop first line
          .map { |line| parse_ls_line(line) }
          .reject { |e| ['.', '..'].include?(e[:name]) }
      end

      def parse_ls_line(line)
        list = line.split
        {
          name: list[8],
          path: File.join(dir, list[8]),
          ftype: FTYPE_NAMES[list[0][0]] || 'unknown',
          mtime: Time.parse(list[5..7].join(' ')),
        }
      end

      def get_list_local(dir)
        check_path(dir)
        log_debug("get list from local: #{dir}")

        unless FileTest.directory?(dir)
          log_warn("not directory: #{dir}")
          return []
        end 

        Dir.entries(dir)
          .reject { |name| ['.', '..'].include?(name)}
          .map do |name|
            path = File.join(dir, name)
            stat = File.stat(path)

            {
              name: name,
              path: path,
              ftype: stat.ftype,
              mtime: stat.mtime,
            }
          end
      end
    end
  end
end
