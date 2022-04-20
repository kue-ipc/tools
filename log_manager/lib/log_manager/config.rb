# frozen_string_literal: true

# = LogManager::Config
# compatible with Ruby 2.0.0
#
# Copyright 2019 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

require 'logger'
require 'yaml'

require_relative 'utils'

module LogManager
  class Config
    include Utils

    DEFAULT_CONFIG = {
      root_dir: '/log',

      logger_file: nil,
      logger_level: Logger::INFO, # 1
      logger_shift: 'weekly',

      file_patterns: [/./],
      file_excludes: [/^\./],

      period_retention: 60 * 60 * 24 * 366 * 2,
      period_nocompress: 60 * 60 * 24 * 2,

      compress_cmd: '/bin/gzip',
      compress_ext: '.gz',
      compress_ext_list: %w[.gz .bz2 .xz .tgz .tbz .txz .zip .7z .Z],

      noop: true,
    }

    attr_reader :logger

    def initialize(config_path = nil, **opts)
      @config_path = config_path || search_config_path
      @config = DEFAULT_CONFIG.merge(load_config).merge(opts)
      @logger = Logger.new(@config[:logger_file] || STDERR,
                           @config[:logger_shift])
      @logger.level = @config[:logger_level]
    end

    def method_missing(name, *args)
      return @config[name] if @config.has_key?(name)

      super(name, *args)
    end

    def search_config_path
      config_path_list = %w[
        /etc/log_manager.yml
        /usr/etc/log_manager.yml
        /usr/local/etc/log_manager.yml
      ] + [File.expand_path('../../etc/log_manager.yml', __dir__)]
      config_path_list.find do |path|
        FileTest.file?(path)
      end
    end

    def load_config
      if @config_path && File.file?(@config_path)
        yaml_load_symbolize(IO.read(@config_path))
      else
        {}
      end
    end

    def path(name)
      case name
      when :root
        @config[:root_dir]
      when :scp
        
      when :rsync
      when :syslog
      end
    end

    def config_yaml
      YAML.dump(@config)
    end
  end
end
