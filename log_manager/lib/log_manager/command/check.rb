require 'log_manager/command/base'
require 'log_manager/utils'

module LogManager
  module Command
    class Check < Base
      def self.command
        'check'
      end

      def run
        start_time = Time.now
        log_info("start: #{start_time}")
        @result ||= {}
        @result[:time] ||= {}
        @result[:time][:start] = start_time

        log_info("root_dir: #{root_dir}")
        @result[:root_dir] = root_dir

        stat = Utils.disk_stat(root_dir)
        log_info("root_path: #{stat.root_path}")
        @result[:disk_path] = stat.root_path

        @result[:block] = stat.block&.merge({usage: stat.block_usage})
        check_block(@result[:block])

        @result[:inode] = stat.inode&.merge({usage: stat.inode_usage})
        check_inode(@result[:inode])

        end_time = Time.now
        @result[:time][:end] = end_time
        log_info("end: #{end_time}")

        self
      end

      def check_block(block)
        if block.nil?
          log_info('no block')
          return
        end

        log_info("block: #{block.to_json}")
        if block[:usage] <= @config[:check][:block_threshold]
          true
        else
          err('block size limit over')
          false
        end
      end

      def check_inode(inode)
        if inode.nil?
          log_info('no inode')
          return
        end

        log_info("inode: #{inode.to_json}")
        if inode[:usage] <= @config[:check][:inode_threshold]
          true
        else
          err('inode size over limit')
          false
        end
      end
    end
  end
end
