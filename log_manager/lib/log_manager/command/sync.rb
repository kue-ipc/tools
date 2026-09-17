require 'resolv'
require 'uri'

require 'log_manager/command/base'

module LogManager
  module Command
    class Sync < Base
      # Sync is an abstract class
      # implement menhods in concrete class
      # - sync

      def run
        start_time = Time.now
        log_info("start: #{start_time}")
        @result ||= {}
        @result[:time] ||= {}
        @result[:time][:start] = start_time

        @result[:sync] ||= []
        all_sync

        end_time = Time.now
        @result[:time][:end] = end_time
        log_info("end: #{end_time}")

        self
      end

      def scheme
        command
      end

      def save_dir
        @save_dir ||=
          File.expand_path(command_dig(:save_dir), root_dir)
      end

      def add_sync_result(host, dir, sync_result)
        @result ||= {}
        @result[:sync] ||= []
        @result[:sync] << {host: host, dir: dir, result: sync_result}
      end

      def all_sync
        log_info('all sync')
        command_dig(:hosts)&.each do |host|
          next if @host && ![host[:name], host[:host]].include?(@host)

          host_sync(**host)
        rescue => e
          err(e)
        end
      end

      def host_sync(name: nil, host: nil, user: 'root', targets: [])
        raise Error, 'no "host" in hosts' if host.nil? || host.empty?

        name = host_to_name(host) if name.nil?
        raise Error, 'empty name in hosts' if name.empty?

        raise Error, "invalid user: #{user}" if user !~ /\A\w+\z/

        log_info("sync host: #{host} as #{name}")

        host_save_dir = File.join(save_dir, name)

        targets.each do |target|
          target_sync(host, user, host_save_dir, **target)
        rescue => e
          err(e)
        end
      end

      def target_sync(host, user, host_save_dir, name: nil, dir: nil, **opts)
        raise Error, 'no "dir" in targets' if dir.nil? || dir.empty?
        raise Error, "no absolute path: #{dir}" unless File.absolute_path?(dir)

        name = File.basename(dir) if name.nil?
        raise Error, 'empty name in hosts' if name.empty?

        log_info("sync target: #{dir} as #{name}")

        target_save_dir = File.join(host_save_dir, name)

        src = create_uri(user: user, hostname: host, path: dir)
        dst = target_save_dir

        begin
          sync_result = sync(src, dst, **opts)
          add_sync_result(host, dir, sync_result)
        rescue => e
          add_sync_result(host, dir, e.message)
          err(e)
        end
      end

      def create_uri(user: nil, password: nil, hostname: nil, **opts)
        uri = URI::Generic.build({scheme: scheme, **opts})
        uri.user = user if user
        uri.password = password if password
        uri.hostname = hostname if hostname
        uri
      end

      def host_type(host)
        case host
        when Resolv::IPv6::Rege
          :ipv6
        when Resolv::IPv4::Regex
          :ipv4
        when /\A[\w-]+\z/
          :hostname
        when /\A(?:[\w-]+\.)+[\w-]+\z/
          :fqdn
        else
          raise Error, "invalid host: #{host}"
        end
      end

      def host_to_name(host)
        case host_type(host)
        when :fqdn
          host.split('.').first
        when :ipv6
          host.gsub(':', '_')
        else
          host
        end
      end
    end
  end
end
