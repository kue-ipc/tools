# frozen_string_literal: true

# LogManager::Rsync
# compatible with Ruby 2.0.0
#
# (c) 2019 Kyoto University of Education
# The MIT License
# https://opensource.org/licenses/MIT

# TODO
# multiple sources required by ssh forced-commands-only

require_relative 'common'

module LogManager
  class Rsync < Common
    RSYNC = %w[/usr/bin/rsync -auzv --no-o --no-g --chmod=D0755,F0644 --rsh=ssh]
              .freeze

    def initialize(**opts)
      super(opts)
    end

    def sync(remote, src, dst, includes: [], excludes: [])
      check_path(dst)
      begin
        make_dir(dst)
        cmd = [
          *RSYNC,
          *includes.map { |pattern| "--include=#{pattern}" },
          *excludes.map { |pattern| "--exclude=#{pattern}" },
          "#{remote}:#{src}/",
          "#{dst}/"
        ]
        run_cmd(cmd)
      rescue => e
        log_error("error occured #{e.class}: #{@host}:#{@target_dir}")
        log_error("error message: #{e.message}")
      end
    end
  end
end
