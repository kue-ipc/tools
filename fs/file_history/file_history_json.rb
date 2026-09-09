#! ruby
# frozen_string_literal: true

# = ファイルアクセスログ
# バージョン 0.0.0
# The MIT License
# Copyrwrite (c) 2023 Kyoto University of Education
#
# == ドキュメント
# https://learn.microsoft.com/ja-jp/windows/security/threat-protection/auditing/security-auditing-overview
#
# == イベントID
# - 4624 S - Logon ログオン成功
# - 4625 - F Logon ログオン失敗
# - 4634 S - Logoff ログオフ
# - 4656 S F File System ハンドル開く
# - 4658 S - File System ハンドル閉じる
# - 4663 S - File System アクセス試行
# - 4670 S - Authorization Policy Change ACL変更
# - 5140 S F File Share 共有アクセス
# - 5145 S F Detailed File Share 共有オブジェクトチェック
#
# == 監査ポリシー
# - オブジェクト アクセス
#     - ファイル システム  {0CCE921D-69AE-11D9-BED3-505054503030}
#     - ハンドル操作       {0CCE9223-69AE-11D9-BED3-505054503030}
#     - ファイルの共有     {0CCE9224-69AE-11D9-BED3-505054503030}
#     - 詳細なファイル共有 {0CCE9244-69AE-11D9-BED3-505054503030}
#
#--
# rubocop: disable Layout/LineLength
# ```
# auditpol /set /subcategory:"{0CCE921D-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
# auditpol /set /subcategory:"{0CCE9223-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
# auditpol /set /subcategory:"{0CCE9224-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
# auditpol /set /subcategory:"{0CCE9244-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
# auditpol /get /category:*
# ```
# rubocop: enable Layout/LineLength
#++

require 'win32ole'
require 'zlib'
require 'json'
require 'yaml'

require_relative 'wmi/nt_log_event'

if $0 == __FILE__
  now = Time.now
  today_begin = Time.local(now.year, now.mon, now.day)

  log_dir = 'D:/FileHistoryLog'
  Dir.mkdir(log_dir) unless FileTest.directory?(log_dir)
  log_file = File.join(log_dir, "#{now.strftime('%Y%m%d_%H%M%S')}.log")

  queue_size = 8
  event_queue = Thread::SizedQueue.new(queue_size)
  event_data_queue = Thread::SizedQueue.new(queue_size)

  log_write_th = Thread.start do
    Zlib::GzipWriter.open("#{log_file}.gz") do |gz|
      while (event_data = event_data_queue.pop)
        gz.puts JSON.fast_generate(event_data)
      end
    end
  end

  pares_event_th = Thread.start do
    while (event = event_queue.pop)
      log_event = Wmi::NTLogEvent.new(event)
      event_data_queue << {
        event_id: log_event.event_identifier,
        event_type: log_event.event_type,
        time_created: log_event.time_generated.to_i,
        event_record_id: log_event.record_number,
        event_data: log_event.event_data,
      }
    end
    event_data_queue.close
  end

  event_list = [
    4624, 4625, 4634,
    4656, 4658, 4663, 4670,
    5140, 5145,
  ]

  where = <<~WHERE
    Logfile = "Security"
    And (#{event_list.map {|num| "EventCode = #{num}" }.join(' OR ')})
  WHERE
  # And TimeGenerated >= \"#{Wmi::Datetime.wql_datetime(today_begin)}\""
  # And TimeGenerated >= \"#{Wmi::Datetime.wql_datetime(today_begin)}\""

  Wmi::NTLogEvent.each_event(where) do |event|
    print '.'
    event_queue << event
  end
  event_queue.close

  [log_write_th, pares_event_th].each(&:join)
end
