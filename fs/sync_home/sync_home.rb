# fs ipcwin

$: << File.join(__dir__, 'lib')

require 'open3'
require 'logger'
require 'set'

require 'active_directory'
require 'file_server'

def run(cmd, logger: Logger.new($stderr))
  logger.info("Run: #{cmd.join(' ')}")
  o, e, s = Open3.capture3(*cmd)
  logger.info("-- status: #{s.exitstatus}")
  logger.info("-- stdout: #{o}")
  logger.info("-- stderr: #{e}") unless e.empty?
  s.exitstatus.zero?
end

if $0 == __FILE__
  log_dir = File.join(__dir__, 'log')
  Dir.mkdir(log_dir) unless FileTest.directory?(log_dir)
  log_file = File.join(log_dir, 'sync_home.log')
  logger = Logger.new(log_file, 'weekly',
                      level: Logger::Severity::INFO,
                      progname: 'sync_home')

  begin
    # TODO: とりあえず、configファイルを読むようにしたけど未テスト
    conf_file = root_path('sync_home.yml')
    unless File.file?(conf_file)
      warn "config file #{conf_file} is missing or not a file"
      exit 1
    end

    begin
      conf = YAML.safe_load_file(conf_file, symbolize_names: true)
    rescue StandardError => e
      warn "failed to load conf file due to #{e.message}"
      exit 2
    end

    logger.info('START')
    domain = conf.dig(:ad, :domain)
    base = conf.dig(:ad, :base)
    ad = ActiveDirectory.new(conf.dig(:ad, :fqdn),
                             base:,
                             user_base: "#{conf.dig(:ad, :user_base)},#{base}",
                             group_base: "#{conf.dig(:ad, :group_base)},#{base}",
                             logger:)
    fs = FileServer.new(conf.dig(:fs, :path), level: conf.dig(:fs, :level), logger:)

    ad_users = ad.users.to_set
    fs_users = fs.users.to_set

    create_users = ad_users - fs_users
    delete_users = fs_users - ad_users
    exist_users = ad_users & fs_users

    create_users.each do |username|
      dir = fs.user_dir(username)
      path = fs.win_path(dir)
      user = "#{domain}\\#{username}"
      logger.info("Create user dir: #{user} #{path}")
      run(['mkdir', path], logger:)
      run(['icacls', path, '/grant:r', "#{user}:(OI)(CI)(M)"], logger:)
      run(['icacls', path, '/setowner', user], logger:)
    rescue => e
      logger.error("Failed to create: #{dir}")
      logger.error(e.message)
    end

    unless delete_users.empty?
      old_path = fs.win_path(fs.old_dir)
      logger.info("Creat old dir: #{old_path}")
      run(['mkdir', old_path], logger:)
    end

    delete_users.each do |username|
      dir = fs.user_dir(username)
      path = fs.win_path(dir)
      dest = fs.win_path(File.join(fs.old_dir, username))
      logger.info("Move user dir: #{path}")
      run(['move', path, dest], logger:)
    end

    logger.info('user count ' \
                "exist: #{exist_users.size}, " \
                "create: #{create_users.size}, " \
                "delete: #{delete_users.size}")
    logger.info('END')
  rescue => e
    logger.error('ERROR')
    logger.error(e.message)
    raise
  end
end
