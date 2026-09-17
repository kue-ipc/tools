require 'time'
require 'log_manager/command/sync'
require 'log_manager/error'

module LogManager
  module Command
    class Scp < Sync
      REMOTE_LS = -'LANG=C ls -l -a -L --full-time'

      FTYPE_NAMES = {
        'b' => 'blockSpecial',
        'c' => 'characterSpecial',
        'd' => 'directory',
        'l' => 'link',
        's' => 'socket',
        'p' => 'fifo',
        '-' => 'file',
      }.freeze

      def self.command
        'scp'
      end

      def ssh_cmd
        @ssh_cmd ||= command_dig(:ssh_cmd)
      end

      def scp_cmd
        @scp_cmd ||= command_dig(:scp_cmd)
      end

      def check_remote_path(path)
        return if %r{\A[\w\-/.+_]+\z} =~ path

        raise Error, "Invalid remote path: #{path}"
      end

      def sync(src, dst, **_opts)
        check_path(dst)
        make_dir(dst)

        count = {copy: 0, skip: 0, excluded: 0, other: 0, error: 0}

        remote_list = get_list_remote(src)
        local_list = get_list_local(dst)

        local_dict = {}
        local_list.each do |local_file|
          local_dict[local_file[:name]] = local_file
        end

        remote_list.each do |remote_file|
          local_file = local_dict[remote_file[:name]]
          sync_result = remote_file_sync(src, dst, remote_file, local_file)
          count[sync_result] += 1 if sync_result
        end

        count
      end

      def remote_file_sync(src, dst, remote_file, local_file,
                           includes: nil, excludes: nil)
        return unless remote_file[:ftype] == 'file'

        name = remote_file[:name]

        if includes&.none? { |ptn| File.fnmatch?(ptn, name) } ||
           excludes&.any? { |ptn| File.fnmatch?(ptn, name) }
          return :excluded
        end

        if local_file && local_file[:ftype] != 'file'
          raise Error, "duplicate with other than file: #{name}"
        end

        if local_file && remote_file[:mtime] <= local_file[:mtime]
          log_warn("skip a newer file: #{name}")
          return :skip
        end

        scp_copy(src, dst, name)

        :copy
      rescue => e
        err(e)
        :error
      end

      def scp_copy(src, dst, name)
        log_info("copy: #{name}")
        cmd = [
          scp_cmd,
          '-p',
          '-q',
          "#{src.user}@#{src.hostname}:#{src.path}/#{name}",
          "#{dst}/#{name}",
        ]
        _, _, status = run_cmd(cmd)
        raise "failed to copy: #{name}" unless status.success?
      end

      def get_list_remote(uri)
        check_remote_path(uri.path)

        log_debug("get list from remote: #{uri}")
        remote = "#{uri.user}@#{uri.hostname}"
        ls_cmd = "#{REMOTE_LS} -- #{uri.path}"
        cmd = [ssh_cmd, remote, ls_cmd]
        stdout, _, status = run_cmd(cmd, noop: false)

        raise Error, "failed to ssh ls: #{uri}" unless status.success?

        stdout.lines
          .drop(1) # drop first line
          .map { |line| parse_ls_line(line, uri.path) }
          .reject { |e| ['.', '..'].include?(e[:name]) }
      end

      def parse_ls_line(line, dir)
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

        raise Error, "not a directory: #{dir}" unless FileTest.directory?(dir)

        Dir.children(dir)
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
