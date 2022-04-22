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
        'd' => 'directory'
        'l' => 'link'
        's' => 'socket'
        'p' => 'fifo'
        '-' => 'file'
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

          remote_names = remote_list.keys
          if includes
            remote_names.select! do |name|
              includes.any?  { |ptn| File.fnmatch?(ptn, name) }
            end
          end

          if excludes
            remote_names.reject! do |name|
              excludes.any?  { |ptn| File.fnmatch?(ptn, name) }
            end
          end

          remote_names.each do |name|
            if local_list.key?(name) &&
               remote_list[name] <= local_list[name]
              log_debug("skip a file: #{name}")
              next
            end

            compressed_name = compressed_path(name)
            if local_list.key?(compressed_name) &&
               remote_list[name] <= local_list[compressed_name]
              log_debug("skip a file (compressed): #{name}")
              next
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
        end
      end

      def get_list_remote(remote, dir)
        check_remote_path(dir)
        log_debug("get list from remote: #{host}:#{dir}")
        ls_cmd = REMOTE_LS + ' -- ' + dir
        cmd = [@ssh_cmd, remote, ls_cmd]
        stdout, stderr, status = run_cmd(cmd)

        if status.nil?
          # noop mode
          return []
        end

        unless status.success?
          log_error("command failed, status: #{status.code}")
          raise Error, 'failed to get remote list'
        end

        file_list = {}
        # skip first line
        stdout.each_line.drop(1).each do |line|
          line_list = line.split
          name = line_list[8]
          next if ['.', '..'].include?(name)

          path = File.join(dir, name)
          ftype = FTYPE_NAMES[line_list[0][0]] || 'unknown'
          mtime = Time.parse(line_list[5..7].join(' '))

          file_list[name] = {
            name: name,
            path: path,
            ftype: ftype,
            mtime: mtime,
          }
        end
        file_list
      end

      def get_list_local(dir)
        check_path(dir)
        log_debug("get list from local: #{dir}")

        file_list = {}
        Dir.foreach(dir) do |name|
          next if ['.', '..'].include?(name)

          path = File.join(dir, name)
          stat = File.stat(path)

          file_list[name] = {
            name: name,
            path: path,
            ftype: stat.ftype,
            mtime: stat.mtime,
          }
        end
        file_list
      end
    end
  end
end
