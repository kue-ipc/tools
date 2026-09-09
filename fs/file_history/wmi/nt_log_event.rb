# Wmi::NTLogEvent wrap Win32_NTLogEvent
# https://learn.microsoft.com/en-us/previous-versions/windows/desktop/eventlogprov/win32-ntlogevent
# class Win32_NTLogEvent
# {
#   uint16   Category;
#   string   CategoryString;
#   string   ComputerName;
#   uint8    Data[];
#   uint16   EventCode;
#   uint32   EventIdentifier;
#   uint8    EventType;
#   string   InsertionStrings[];
#   string   Logfile;
#   string   Message;
#   uint32   RecordNumber;
#   string   SourceName;
#   datetime TimeGenerated;
#   datetime TimeWritten;
#   string   Type;
#   string   User;
# };

require_relative '../wmi'
require_relative 'datetime'

module Wmi
  class NTLogEvent
    NAME = 'Win32_NTLogEvent'

    def self.each_event(where = nil, &block)
      sql = "SELECT * FROM #{Wmi::NTLogEvent::NAME}"
      if where
        sql += " WHERE #{where}"
      end
      Wmi.each_event(sql, &block)
    end

    def self.event_def_dir
      @event_def_dir ||= File.join(__dir__, '..', 'event')
    end

    def self.event_def_dir=(path)
      @event_def_dir = path
    end

    module Types
      # rubocop: disable Naming/ConstantName
      SID = :to_s.to_proc
      GUID = :to_s.to_proc
      UnicodeString = :to_s.to_proc
      HexInt32 = ->(s) { s.to_i(16) }
      HexInt64 = ->(s) { s.to_i(16) }
      Pointer = ->(s) { s.to_i(16) }
      UInt32 = :to_i.to_proc
      # rubocop: enable Naming/ConstantName
    end

    INSERTION_STRINGS_CODE_TYPES = Dir.each_child(event_def_dir)
      .select { |path| path =~ /^\d+.yml$/ }
      .to_h do |path|
        data_list = YAML.load_file(File.join(event_def_dir, path))
        .map do |data|
          [data['name'].gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase.intern,
            Types.const_get(data['type']),]
        end
      [path.delete_suffix('.yml').to_i, data_list]
    end

    attr_reader :category, :category_string, :computer_name, :data,
                :event_code, :event_identifier, :event_type, :insertion_strings,
                :log_file, :message, :record_number, :source_name,
                :time_generated, :time_written, :type, :user

    def initialize(event)
      @category = event.Category
      @category_string = event.CategoryString
      @computer_name = event.ComputerName
      @data = event.Data
      @event_code = event.EventCode
      @event_identifier = event.EventIdentifier
      @event_type = event.EventType
      @insertion_strings = event.InsertionStrings
      @log_file = event.Logfile
      @message = event.Message
      @record_number = event.RecordNumber
      @source_name = event.SourceName
      @time_generated = Datetime.parse_wmi_datetime(event.TimeGenerated)
      @time_written = Datetime.parse_wmi_datetime(event.TimeWritten)
      @type = event.Type
      @user = event.User
    end

    def event_data
      @event_data ||= parse_insertion_strings
    end

    def parse_insertion_strings
      INSERTION_STRINGS_CODE_TYPES[event_code]&.zip(insertion_strings)
        &.to_h { |type, value| [type[0], type[1].call(value)] }
    end
  end
end
