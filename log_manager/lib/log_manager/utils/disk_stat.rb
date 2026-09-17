require 'log_manager/utils/platform'
require 'log_manager/utils/win_kernel32' if LogManager::Utils::Platform.windows?

module LogManager
  module Utils
    class DiskStat
      attr_reader :path, :root_path, :block, :inode

      def initialize(path)
        @path = path

        data =
          case LogManager::Utils::Platform.platform
          when :windows
            DiskStat.disk_data_windows(@path)
          when :linux
            DiskStat.disk_data_linux(@path)
          else
            raise NotImplementedError
          end
        @root_path = data[:path]
        @block = data[:block]
        @inode = data[:inode]
      end

      def block_usage
        usage(@block)
      end

      def inode_usage
        usage(@inode)
      end

      private def usage(data)
        data && data[:used].fdiv(data[:used] + data[:avail])
      end

      def self.disk_data_windows(path)
        path_wstr = path.gsub('/', '\\').encode(Encoding::UTF_16LE)
        vol_size = File.expand_path(path).size + 1
        vol_wstr = ("\0".b * vol_size).encode(Encoding::UTF_16LE)

        if WinKernel32.GetVolumePathNameW(path_wstr, vol_wstr, vol_size).zero?
          raise "Error GetDiskFreeSpaceExW: #{Fiddle.win32_last_error}"
        end

        vol = vol_wstr.encode(Encoding::UTF_8).delete("\0").gsub('\\', '/')

        avail_p = "\0".b * 8
        total_p = "\0".b * 8
        if WinKernel32.GetDiskFreeSpaceExW(path_wstr, avail_p, total_p,
          nil).zero?
          raise "Error GetDiskFreeSpaceExW: #{Fiddle.win32_last_error}"
        end

        avail = avail_p.unpack1('Q')
        total = total_p.unpack1('Q')

        {
          path: vol,
          block: {total: total, used: total - avail, avail: avail},
          inode: nil,
        }
      end

      def self.disk_data_linux(path)
        df_block_data = df_block(path)
        df_inode_data = df_inode(path)
        {
          path: df_block_data[:path],
          block: df_block_data.slice(:total, :used, :avail),
          inode: df_inode_data.slice(:total, :used, :avail),
        }
      end

      def self.df_block(path)
        result = IO.popen(['df', '-B', '1', path]) do |io|
          io.gets
          io.gets&.split
        end
        raise "failed to df block for: #{path}" if !$?.success? || result.nil?

        {
          path: result[5],
          total: result[1].to_i,
          used: result[2].to_i,
          avail: result[3].to_i,
        }
      end

      def self.df_inode(path)
        result = IO.popen(['df', '-i', path]) do |io|
          io.gets
          io.gets&.split
        end
        raise "failed to df inode for: #{path}" if !$?.success? || result.nil?

        {
          path: result[5],
          total: result[1].to_i,
          used: result[2].to_i,
          avail: result[3].to_i,
        }
      end
    end
  end
end

if $0 == __FILE__
  ARGV.each do |path|
    stat = LogManager::Utils::DiskStat.new(path)
    pp stat
    pp stat.block_usage
    pp stat.inode_usage
  end
end
