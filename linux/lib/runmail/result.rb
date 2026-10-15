# frozen_string_literal: true

module Runmail
  class Result
    attr_reader :run, :status, :time, :out, :err, :info

    def initialize(run = nil)
      @run = run
      @status = :unknown
      @time = nil
      @out = String.new
      @err = String.new
      @info = String.new
    end

    def dup
      result = Result.new(run)
      result.status = status
      result.time_update(time)
      result.out_concat(out)
      result.err_concat(err)
      result.info_concat(info)
      result
    end

    def <<(other)
      @run = [@run, other.run].compact.join(" && ")
      @status = other.status
      time_update(other.time)
      out_concat(other.out)
      err_concat(other.err)
      info_concat(other.info)
      self
    end

    def +(other)
      dup << other
    end

    def status=(status)
      @status =
        case status
        in Symbol
          status
        in String
          status.downcase.intern
        in Process::Status
          if status.success?
            :success
          elsif status.exited?
            :failure
          else
            :running
          end
        end
    end

    def first_time
      time&.first
    end

    def last_time
      time&.last
    end

    # time: Time | Range[Time] | Array[Time]
    def time_update(time = Time.now)
      return @time if time.nil? # do nothing

      if !time.is_a?(Time)
        # must be Range or Array-like
        time_update(time.first)
        time_update(time.last)
      elsif @time.nil?
        @time = Range.new(time, time)
      elsif time < @time.first
        @time = Range.new(time, @time.last)
      elsif time > @time.last
        @time = Range.new(@time.first, time)
      else
        # do nothing
        @time
      end
    end

    def out_concat(str)
      @out << str
    end

    def err_concat(str)
      @err << str
    end

    def info_concat(str)
      @info << str
    end

    def success?
      @status == :success
    end

    def out_omit(pattern)
      omitted_out = String.new
      @out.each_line do |line|
        omitted_out << line if line !~ pattern
      end
      @out = omitted_out
    end
  end
end
