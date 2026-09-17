require 'logger'
require 'yaml'
require 'json'
require 'fileutils'
require 'forwardable'

require 'log_manager/error'
require 'log_manager/utils'

module LogManager
  class Config
    extend Forwardable
    include Utils

    DEFAULT_CONFIG = {
      log: {
        file: 'log_manager/log_manager.log',
        level: 'info',
        shift: 'weekly',
      },

      mail: {
        smtp: {
          server: 'localhost',
          port: 25,
        },
      },

      check: {
        block_threshold: 0.8,
        inode_threshold: 0.8,
      },

      clean: {
        period_retention: 60 * 60 * 24 * 366 * 2, # 2 years
        period_nocompress: 60 * 60 * 24 * 2,      # 2 days
        compress: {
          cmd: 'gzip',
          ext: '.gz',
          ext_list: %w[.gz .bz2 .xz .tgz .tbz .txz .zip .7z],
        },
      },

      rsync: {
        cmd: 'rsync',
        save_dir: 'rsync',
      },

      scp: {
        ssh_cmd: 'ssh',
        scp_cmd: 'scp',
        save_dir: 'scp',
      },
    }.freeze

    attr_reader :path, :log_file, :root_dir

    def initialize(path)
      @path = path
      @config = hash_deep_merge(DEFAULT_CONFIG, load_config || {})

      @root_dir = check_root_dir(@config[:root_dir])

      @log_file = File.expand_path(@config[:log][:file], @root_dir)

      unless FileTest.directory?(File.dirname(@log_file))
        FileUtils.mkpath(File.dirname(@log_file))
      end

      @logger = Logger.new(@log_file, @config[:log][:shift],
        progname: 'log_manager')
      self.log_level = @config.dig(:log, :level)
    end

    def_delegators :@config, :[], :dig, :fetch, :to_h

    def_delegators :@logger, :log, :progname
    def_delegators :@logger, :fatal, :error, :warn, :info, :debug, :unknown

    private def check_root_dir(dir)
      raise Error, 'root_dir is not set or empty' if dir.nil? || dir.empty?

      path = File.expand_path(dir)
      unless FileTest.directory?(path)
        raise Error, "root_dir is not a directory: #{path}"
      end

      path
    end

    def log_level=(level)
      @logger.level =
        case level
        when Integer then level
        when /^UNKNOWN$/i then Logger::UNKNOWN
        when /^FATAL$/i then Logger::FATAL
        when /^ERROR$/i then Logger::ERROR
        when /^WARN$/i then Logger::WARN
        when /^INFO$/i then Logger::INFO
        when /^DEBUG$/i then Logger::DEBUG
        else
          raise LogManager::Error,
            "unknown logger level - #{level}"
        end
    end

    def log_level
      @logger.level
    end

    def load_config
      YAML.safe_load(File.read(path), symbolize_names: true)
    end

    def dump_config
      YAML.dump(hash_stringify_names(@config))
    end
  end
end
