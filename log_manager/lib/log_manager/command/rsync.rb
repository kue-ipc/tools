# frozen_string_literal: true

# LogManager::Rsync
# compatible with Ruby 2.0.0
#
# (c) 2019 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

# TODO
# multiple sources required by ssh forced-commands-only

require 'log_manager/command/base'

module LogManager
  module Command
    class Rsync < Base
      RSYNC_OPTIONS = %w[
        -auzv
        --no-o
        --no-g
        --chmod=D0755,F0644
        --rsh=ssh
      ].freeze

      def self.run(**opts)
        Rsync.new(**opts).all_sync
      end

      def initialize(host: nil, **opts)
        super
        @host = host
        @save_dir = File.expand_path(@config[:rsync][:save_dir], @config[:root_dir])
        @rsync_cmd = @config[:rsync][:cmd]
      end

      def all_sync
        @config[:rsync][:hosts].each do |host|
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
        check_path(dst)
        begin
          make_dir(dst)
          cmd = [
            @rsync_cmd,
            *RSYNC_OPTIONS,
            *(includes || []).map { |pattern| "--include=#{pattern}" },
            *(excludes || []).map { |pattern| "--exclude=#{pattern}" },
            "#{remote}:#{src}/",
            "#{dst}/"
          ]
          run_cmd(cmd)
        rescue => e
          log_error("error message: #{e.message}")
        end
      end
    end
  end
end