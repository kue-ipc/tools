# frozen_string_literal: true

# combine ruby script

require "yaml"

def combine(path, list)
  data = {}
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
      require_path += ".rb" unless File.exist?(require_path) || require_path.end_with?(".rb")
      unless list.include?(require_path)
        print "# --- begin --- #{line}"
        data.merge!(combine(require_path, list))
        print "# --- end --- #{line}"
      end
    when /\bYAML\.safe_load_file\b/
      m = /\bYAML\.safe_load_file\(\s*"([^"]+)"/.match(line)
      unless m
        raise "Invalid YAML.safe_load_file line: (#{path}:#{index + 1}) #{line}"
      end

      yaml_path = m[1]
        .sub(/\#\{\s*__dir__\s*\}/, File.dirname(path))
        .sub(/\#\{\s*__FILE__\s*\}/, path)
      yaml_path = File.expand_path(yaml_path)
      warn "yaml #{yaml_path}"
      data.merge!(YAML.safe_load_file(yaml_path))
      print line.sub(/\bYAML\.safe_load_file\(\s*"([^"]+)"/, "YAML.safe_load(DATA")
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
  puts "__END__"
  YAML.safe_dump(data, $stdout)
end
