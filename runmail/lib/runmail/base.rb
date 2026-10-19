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

    def runmail(...)
      result = run(...)
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

    def run(*cmd, **)
      result = Result.new(cmd_line(*cmd))
      @logger&.info { "run: #{result.run}" }
      result.time_update
      out, err, status = run_capture(*cmd, **)
      result.time_update
      @logger&.info { "run status: #{status_to_s(status)}" }
      @logger&.debug { "run out: #{out.dup.force_encoding('UTF-8').inspect}" } if out&.size&.positive?
      @logger&.warn { "run err: #{err.dup.force_encoding('UTF-8').inspect}" } if err&.size&.positive?
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

    private def run_capture(*cmd, timeout: @timeout, **)
      out = String.new
      err = String.new
      stdout_data = [out]
      stderr_data = [err]
      unless @quiet
        stdout_data << $stdout
        stderr_data << $stderr
      end
      status = nil
      begin
        Timeout.timeout(timeout) do
          status = run_capture_inner(*cmd, stdout_data:, stderr_data:, **)
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

    private def run_capture_inner(*cmd, stdout_data: [], stderr_data: [], stdin_data: nil, binmode: false, **)
      readers = []
      stdin, stdout, stderr, wait_thr = run_popen(*cmd, **)
      [stdin, stdout, stderr].compact.each(&:binmode) if binmode
      readers << copy_partial_thread(stdout, stdout_data)
      readers << copy_partial_thread(stderr, stderr_data)
      stdin.write stdin_data if stdin_data&.size&.positive?
      stdin.close
      wait_thr.value
    ensure
      readers.compact.each(&:join)
    end

    private def run_popen(*cmd, stderr: @stderr, **)
      if @dry_run
        @logger&.info { "dry_run: #{cmd_line(*cmd)}" }
        return [StringIO.new, StringIO.new, StringIO.new, Thread.new { :noop }]
      end

      case stderr
      in :stderr
        Open3.popen3(*cmd, **)
      in :stdout
        stdin, stdout, wait_thr = Open3.popen2e(*cmd, **)
        stderr = nil
        [stdin, stdout, stderr, wait_thr]
      in :null | nil
        stdin, stdout, wait_thr = Open3.popen2(*cmd, **)
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
