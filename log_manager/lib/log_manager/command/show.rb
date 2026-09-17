require 'log_manager/command/base'

module LogManager
  module Command
    class Show < Base
      def self.command
        'show'
      end

      def run
        log_info("config_path: #{@config.path}")
        puts "# config_path: #{@config.path}"
        puts @config.dump_config
        @result = {
          path: @config.path,
          config: @config.to_h,
          log_file: @config.log_file,
        }
        self
      end
    end
  end
end
