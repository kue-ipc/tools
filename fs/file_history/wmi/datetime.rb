module Wmi
  module Datetime
    # https://learn.microsoft.com/ja-jp/windows/win32/wmisdk/cim-datetime

    PARSE_RE = /\A
      (?<year>\d{4})
      (?<mon>\d{2})
      (?<day>\d{2})
      (?<hour>\d{2})
      (?<min>\d{2})
      (?<sec>\d{2})
      \.
      (?<usec>\d{6})
      (?<zone>[+-]\d{3})
    \z/x

    module_function def parse_wmi_datetime(datetime)
      m = PARSE_RE.match(datetime)
      raise "invalid wmi datemite: #{datetime}" unless m

      time = Time.new(
        m[:year].to_i,
        m[:mon].to_i,
        m[:day].to_i,
        m[:hour].to_i,
        m[:min].to_i,
        m[:sec].to_i,
        m[:zone].to_i * 60)
      Time.at(time.to_i, m[:usec].to_i)
    end

    module_function def wmi_datetime(time)
      time.utc.strftime('%Y%m%d%H%M%S.%6N-000')
    end

    module_function def wql_datetime(time)
      time.utc.strftime('%Y-%m-%d %H:%M:%S:%3N')
    end
  end
end
