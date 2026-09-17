module LogManager
  module Utils
    module Platform
      def self.windows?
        platform == :windows
      end

      def self.platform
        @platform ||=
          case RUBY_PLATFORM
          when /mingw|mswin/
            :windows
          when /linux/
            :linux
          when /darwin/
            :mac
          when /freebsd|openbsd/
            :bsd
          when /solaris/
            :solaris
          when /java/
            :java
          else
            :other
          end
      end
    end
  end
end
