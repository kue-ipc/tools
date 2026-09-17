require 'optparse'
require 'yaml'
require 'net/smtp'

require 'log_manager'
require 'log_manager/config'
require 'log_manager/command/check'
require 'log_manager/command/clean'
require 'log_manager/command/rsync'
require 'log_manager/command/scp'
require 'log_manager/command/show'

module LogManager
  module Command
    def self.run(argv, config_path_list = [])
      begin
        commands, opts, help = opt_parse(argv)
      rescue OptionParser::ParseError => e
        warn e.message
        warn help
        return 0x10
      end

      if commands.empty?
        warn 'no command'
        warn help
        return 0x11
      end

      unknown_commands = commands - %w[check clean rsync scp show]

      unless unknown_commands.empty?
        warn "unknownt command: #{unknown_commands.join(', ')}"
        return 0x12
      end

      config_path_list = [opts[:config]] if opts[:config]
      config_path = config_path_list.find { |path| FileTest.exist?(path) }
      if config_path.nil?
        warn 'not found a config file'
        return 0x13
      end

      config = Config.new(config_path)
      results = run_commands(commands, config, **opts)

      send_mail(results, config) if opts[:mail]

      if results.all?(&:success?)
        config.info { 'success' }
        puts 'success'
        0
      else
        config.error { 'failure' }
        warn 'failure'
        1
      end
    end

    def self.opt_parse(argv)
      parser = OptionParser.new

      parser.version = LogManager::VERSION

      parser.on('-c CONFIG', '--config=CONFIG', 'specify config', &:itself)
      parser.on('-h HOST', '--host=HOST', 'speify romote host', &:itself)
      parser.on('-n', '--noop', 'no operation', &:itself)
      parser.on('-m', '--mail', 'send results by mail ', &:itself)
      parser.on('-s', '--stop', 'stop if failure', &:itself)

      parser.banner = <<~BANNER
        Usage: #{$0} [options...] commands...
          commands:
            check                            check log disk
            clean                            clean add compress log
            rsync                            rsync log from remote
            scp                              scp log from remote
            show                             show config
          options:
      BANNER

      opts = {}
      commands = parser.parse(argv, into: opts)
      [commands, opts, parser.help]
    end

    def self.run_commands(commands, config, **opts)
      results = []
      commands.each do |command|
        results <<
          case command
          when 'check' then Command::Check.run(config, **opts)
          when 'clean' then Command::Clean.run(config, **opts)
          when 'rsync' then Command::Rsync.run(config, **opts)
          when 'scp' then Command::Scp.run(config, **opts)
          when 'show' then Command::Show.run(config, **opts)
          else raise "unknown command: #{command}"
          end
        if opts[:stop] && !results.last.success?
          warn 'stop by failure'
          break
        end
      end
      results
    end

    def self.send_mail(results, config)
      result =
        if results.all?(&:success?)
          'SUCCESS'
        else
          'FAILURE'
        end
      date = Time.now.strftime('%Y-%m-%d')
      host = `hostname`.chomp
      subject = "Log Manager [#{host}] {#{date}} #{result}"

      from = config.dig(:mail, :from)
      to = Array(config.dig(:mail, :to)).compact
      raise 'mail.from is not set or empty' if from.nil? || from.empty?
      raise 'mail.to is not set or empty' if to.empty?

      message = <<~MESSAGE
        Log Manager

        Host: #{host}
        Date: #{date}
        Result: #{result}
        Config: #{config.path}
        Commands: #{results.map(&:command).join(' ')}
        ---
      MESSAGE
      results.each do |r|
        message << "Command: #{r.command}\n"
        if r.success?
          message << "Result: SUCCESS\n"
        else
          message << "Result: FAILURE\n"
          r.errors.each do |error|
            message << "Error: #{error}\n"
          end
        end
        message << YAML.dump(r.result)
        message << "---\n"
      end

      mail = <<~MAIL
        From: #{from}
        To: #{to.join(', ')}
        Subject: #{subject}

        #{message}
      MAIL

      begin
        config.info { 'send mail' }
        Net::SMTP.start(config.dig(:mail, :smtp, :server),
          config.dig(:mail, :smtp, :port)) do |smtp|
          smtp.send_message(mail, from, to)
        end
      rescue => e
        config.error { 'failed to send mail' }
        config.error { e.message }
        raise
      end
    end
  end
end
