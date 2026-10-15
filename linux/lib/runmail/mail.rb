# frozen_string_literal: true

require "net/smtp"
require "etc"
require "socket"

module Runmail
  class Mail
    def initialize(progname: self.class.name, from: nil, to: nil, smtp: {}, logger: nil)
      @progname = progname
      @from = from || current_user_address
      @to = to || @from
      @smtp = {server: "localhost", port: Net::SMTP.default_port, **smtp}
      @logger = logger
    end

    def mail(result)
      @logger&.info { "mail: #{result.run}" }
      message = String.new
      message << mail_header(result)
      message << "\n"
      message << mail_body(result)

      send_mail(message)
      @logger&.info { "mail - sent to #{@to}" }
    end

    def hostname
      @hostname ||= Socket.gethostname
    end

    def hostname_short
      @hostname_short ||= hostname.split(".", 2).first
    end

    private def current_user_address
      "#{Etc.getlogin}@#{hostname}"
    end

    private def send_mail(message)
      message = message.gsub(/\R/, "\r\n")
      smtp = Net::SMTP.new(@smtp[:server], @smtp[:port])

      case @smtp[:starttls]
      when "auto", :auto
        smtp.enable_starttls_auto
      when "always", :always, true
        smtp.enable_starttls
      end
      smtp.enable_tls if @smtp[:tls]

      smtp_start_opts = @smtp.slice(:user, :password, :authtype)

      smtp.start(hostname, **smtp_start_opts) do
        @logger&.debug { "smtp - start" }
        smtp.send_message(message, @from, @to)
        @logger&.debug { "smtp - sned #{message.size} bytes message" }
      end
    end

    private def mail_header(result)
      <<~MAIL_HEADER
        From: #{@from}
        To: #{@to}
        #{subject(result)}
        Content-Type: text/plain; charset="UTF-8"
        Content-Transfer-Encoding: base64
      MAIL_HEADER
    end

    private def mail_body(result)
      body = String.new
      body << info(result)
      [:out, :err].select do |name|
        result.public_send(name)&.size&.positive?
      end.each do |name|
        body << "\n--- #{name} ---\n"
        body << result.public_send(name)
      end
      Base64.encode64(body.force_encoding(Encoding::UTF_8))
    end

    private def subject(result, max_length: 78)
      time = result.first_time || Time.now
      status = result.status&.to_s&.upcase || "UNKNOWN"
      info = result.info
      info = result.run unless info&.size&.positive?
      header = "Subject: #{@progname} [#{hostname_short}] #{time.strftime('%Y-%m-%d')} (#{status})"
      header += " #{info}" if info&.size&.positive?
      header.delete("^ -~")[0, max_length]
    end

    private def info(result)
      <<~INFO
        #{@progname}

        Hostname: #{hostname}
        Run: #{result.run}
        Status: #{result.status}
        Time: #{result.time}
        Info: #{result.info}
      INFO
    end
  end
end
