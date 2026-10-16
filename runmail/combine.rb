# frozen_string_literal: true

# combine ruby script

require "yaml"

def combine(path, list, data = nil)
  list << path
  warn "combine #{path}"
  script = File.read(path)
  script.each_line.with_index do |line, index|
    case line
    when /\brequire_relative\b/
      m = /^\s*require_relative\s*(\()?\s*(["'])([^"']+)\2\s*(?(1)\))\s*$/.match(line)
      unless m
        raise "Invalid require_relative line: (#{path}:#{index + 1}) #{line}"
      end

      require_path = File.expand_path(m[3], File.dirname(path))
      require_path += ".rb" unless require_path.end_with?(".rb")
      unless list.include?(require_path)
        print "# --- begin --- #{line}"
        data = combine(require_path, list, data)
        print "# --- end --- #{line}"
      end
    when /\bDATA_FILE\s*=(?!=)/
      if data
        raise "Multiple DATA_FILE lines: (#{path}:#{index + 1}) #{line}"
      end

      m = /\bDATA_FILE\s*=\s*"((?:[^"]|\#\{[^}]+\})+)"/.match(line)
      unless m
        raise "Invalid DATA_FILE line: (#{path}:#{index + 1}) #{line}"
      end

      data_file = m[1].dup
      [
        [/\#\{\s*__dir__\s*\}/, File.dirname(path)],
        [/\#\{\s*__FILE__\s*\}/, path],
        [/\#\{\s*File.basename\s*\(\s*__FILE__\s*\)\s*\}/, File.basename(path)],
        [/\#\{\s*File.basename\s*\(\s*__FILE__\s*,\s*"\.\*"\s*\)\s*\}/, File.basename(path, ".*")],
      ].each do |pattern, replacement|
        data_file.gsub!(pattern, replacement)
      end
      if data_file.include?("\#{")
        raise "Unconvertable DATA_FILE line: (#{path}:#{index + 1}) #{line}"
      end

      if File.exist?(data_file)
        warn "read #{data_file}"
        data = File.read(data_file)
      end
      print line
    else
      print line
    end
  end
  data
end

if $0 == __FILE__
  if ARGV.empty?
    warn "Usage: #{$0} [script]"
    exit 1
  end

  data = combine(File.expand_path(ARGV.first), [])
  if data
    puts "__END__"
    print data
  end
end
