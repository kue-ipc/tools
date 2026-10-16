# frozen_string_literal: true

require "yaml"
require "open3"
require "timeout"
require "base64"
require "socket"
require "logger"

require_relative "result"
require_relative "mail"

module Runmail
  class Base
    # progname: String
    # timeout: Integer
    # stderr: Symbol (:stderr, :stdout, :null, nil)
    #   :stderr: stderr redirect to stderr
    #   :stdout: stderr redirect to stdout
    #   :null: stderr redirect to /dev/null
    #   nil: same :null
    # mail: Hash (see send_mail)
    # log: Hash (see Logger.new)
    def initialize(progname: self.class.name,
        timeout: 3600,
        stderr: :stderr,
        dry_run: false,
        quiet: false,
        log: {},
        mail: {})
      @progname = progname
      @timeout = timeout
      @stderr = stderr&.to_sym || :null

      @dry_run = dry_run
      @quiet = quiet

      log = log.dup
      log&.delete(:dir)&.tap do |dir|
        log[:file] ||= "#{dir}/#{@progname}.log"
      end
      @logger = log && create_logger(**log)
      @mail = mail && Runmail::Mail.new(progname: @progname, logger: @logger, **mail)
    end

    def create_logger(file: nil, age: nil, size: nil, level: :debug, progname: @progname)
      Logger.new(file || $stdout, age || 0, size || 1048576, level:, progname:)
    end

    def runmail(*cmd)
      result = run(*cmd)
      mail(result)
      result
    rescue => e
      @logger&.error { e.full_message(highlight: false, order: :top) }
      raise
    end

    def run_cat(*cmd_list, **opts)
      result = Result.new
      cmd_list.each do |cmd|
        result << run(*cmd, **opts)
        break unless result.success?
      end
      result
    end

    def run(*cmd, **opts)
      result = Result.new(cmd_line(*cmd))
      @logger&.info { "run: #{result.run}" }
      result.time_update
      out, err, status = run_capture(*cmd, **opts)
      result.time_update
      @logger&.info { "run status: #{status_to_s(status)}" }
      @logger&.debug { "run out: #{out.dup.force_encoding("UTF-8").inspect}" } if out&.size&.positive?
      @logger&.warn { "run err: #{err.dup.force_encoding("UTF-8").inspect}" } if err&.size&.positive?
      result.status = status
      result.out_concat(out)
      result.err_concat(err)
      result
    end

    def status_to_s(status)
      case status
      in Process::Status
        if status.success?
          "success"
        elsif status.exited?
          "failure (#{status.exitstatus})"
        else
          "running"
        end
      in Symbol | String
        status.to_s
      end
    end

    def mail(result)
      @mail&.mail(result)
    end

    # see Kernel.#spawn parameters
    def cmd_line(*cmd)
      cmd.shift if cmd.first.is_a?(Hash)
      cmd[0] = cmd[0].first if cmd.first.is_a?(Array)
      cmd.join(" ")
    end

    private def run_capture(*cmd, timeout: @timeout, stdin_data: nil, binmode: false, **opts)
      out = String.new
      err = String.new
      status = nil
      begin
        Timeout.timeout(timeout) do
          stdin, stdout, stderr, wait_thr = run_popen(*cmd, **opts)
          [stdin, stdout, stderr].compact.each(&:binmode) if binmode
          readers = [
            copy_partial_thread(stdout, [out, @quiet ? nil : $stdout].compact),
            copy_partial_thread(stderr, [err, @quiet ? nil : $stderr].compact),
          ]
          stdin.write stdin_data if stdin_data&.size&.positive?
          stdin.close
          status = wait_thr.value
          readers.compact.each(&:join)
        end
      rescue Timeout::Error
        status = :timeout
        @logger&.error { "timeout" }
      rescue => e
        status = :error
        @logger&.error { e.full_message(highlight: false, order: :top) }
        err << e.full_message(highlight: false, order: :top)
      end
      Thread.pass
      [out, err, status]
    end

    private def run_popen(*cmd, stderr: @stderr, **opts)
      if @dry_run
        @logger&.info { "dry_run: #{cmd_line(*cmd)}" }
        return [StringIO.new, StringIO.new, StringIO.new, Thread.new { :noop }]
      end

      case stderr
      in :stderr
        Open3.popen3(*cmd, **opts)
      in :stdout
        stdin, stdout, wait_thr = Open3.popen2e(*cmd, **opts)
        stderr = nil
        [stdin, stdout, stderr, wait_thr]
      in :null | nil
        stdin, stdout, wait_thr = Open3.popen2(*cmd, **opts)
        stderr = nil
        [stdin, stdout, stderr, wait_thr]
      end
    end

    private def copy_partial_thread(src, dst, maxlen: 4096)
      return if src.nil? || src.closed?
      dst = [dst] unless dst.is_a?(Array)

      Thread.new do
        loop do
          src.readpartial(maxlen).then do |data|
            dst.each { |d| d << data }
          end
        rescue EOFError
          break
        end
      end
    end
  end
end
