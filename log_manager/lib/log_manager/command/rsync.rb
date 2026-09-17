# TODO
# * multiple sources required by ssh forced-commands-only

require 'resolv'

require 'log_manager/command/sync'

module LogManager
  module Command
    class Rsync < Sync
      RSYNC_OPTIONS = %w[
        -a
        -u
        -z
        -v
        --no-o
        --no-g
        --chmod=D0755,F0644
        --rsh=ssh
      ].freeze

      def self.command
        'rsync'
      end

      def rsync_cmd
        @rsync_cmd ||= command_dig(:cmd)
      end

      def sync(src, dst, **opts)
        check_path(dst)
        make_dir(dst)

        rsync_src = "#{src.user}@#{src.host}:#{src.path}"
        rsync_dst = dst
        rsync_src += '/' unless rsync_src.end_with?('/')
        rsync_dst += '/' unless rsync_dst.end_with?('/')

        rsync(rsync_src, rsync_dst, **opts)
      end

      def rsync(rsync_src, rsync_dst, includes: nil, excludes: nil)
        raise Error, "invalid rsnyc src: #{rsync_src}" if rsync_src =~ /^-/
        raise Error, "invalid rsnyc dst: #{rsync_dst}" if rsync_dst =~ /^-/

        opts = []
        opts << '-n' if @noop
        opts.concat(RSYNC_OPTIONS)
        includes&.each { |pattern| opts << "--include=#{pattern}" }
        excludes&.each { |pattern| opts << "--exclude=#{pattern}" }
        cmd = [
          rsync_cmd,
          *opts,
          rsync_src,
          rsync_dst,
        ]
        stdout, _, status = run_cmd(cmd)
        raise Error, "failed to rsnyc: #{rsync_src}" unless status.success?

        stdout
      end
    end
  end
end
