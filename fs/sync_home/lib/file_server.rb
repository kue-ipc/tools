require 'logger'
require 'digest/xxhash'

class FileServer
  def initialize(root, level: 0, chars: 2, digest: Digest::XXH32,
                 logger: Logger.new($stderr))
    @root = root
    @level = level
    @chars = chars
    @digest = digest
    @logger = logger
    @datestr = Time.now.strftime('%Y%m%d')
  end

  def sub_dir(username)
    return [] if @level.zero?

    @digest.hexdigest(username)
      .each_char.each_slice(@chars).map(&:join)[0, @level]
  end

  def user_dir(username)
    File.join(@root, *sub_dir(username), username)
  end

  def users
    dirs.map do |dir|
      username = File.basename(dir)
      if user_dir(username) == dir
        username
      else
        @logger.warn("Invaild dir: #{dir}")
        nil
      end
    end.compact
  end

  def dirs
    find_dirs(@root, @level)
  end

  def find_dirs(parent, level)
    Dir.children(parent).flat_map do |child|
      child_path = File.join(parent, child)
      if child.start_with?('.')
        @logger.info("Skip sub dir: #{child_path}")
        nil
      elsif level.zero?
        child_path
      elsif FileTest.directory?(child_path) && child =~ Regexp.new("^#{'\\h' * @chars}$")
        find_dirs(child_path, level - 1)
      else
        @logger.warn("Invaild sub dir: #{child_path}")
        nil
      end
    end.compact
  end

  def win_path(path)
    path.gsub('/', '\\\\')
  end

  def old_dir
    @old_dir ||= File.join(@root, '.old', @datestr)
  end
end
