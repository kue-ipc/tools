# frozen_string_literal: true

# Sched VSS -  Scheduling Volume Shadow Copy
# version 0.1.2
# The MIT License
# Copyrwrite (c) 2023 Kyoto University of Education

require 'win32ole'
require 'net/smtp'
require 'yaml'
require 'logger'
require 'json'
require 'time'
require 'socket'

module Wmi
  def self.service
    @service ||= WIN32OLE.new('WbemScripting.SWbemLocator')
      .ConnectServer('.', 'root/cimv2')
  end

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

    module_function

    def parse_wmi_datetime(datetime)
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

    def wmi_datetime(time)
      time.utc.strftime('%Y%m%d%H%M%S.%6N-000')
    end

    def wql_datetime(time)
      time.utc.strftime('%Y-%m-%d %H:%M:%S:%3N')
    end
  end

  # rubocop: disable Metrics/AbcSize, Metrics/MethodLength

  # ShadowCopy wrap Win32_ShadowCopy
  # https://learn.microsoft.com/en-us/previous-versions/windows/desktop/legacy/aa394428(v=vs.85)
  # class Win32_ShadowCopy : CIM_LogicalElement
  # {
  #   string   Caption;
  #   string   Description;
  #   string   ID;
  #   datetime InstallDate;
  #   string   Name;
  #   string   SetID;
  #   string   ProviderID;
  #   string   Status;
  #   uint32   Count;
  #   string   DeviceObject;
  #   string   VolumeName;
  #   string   OriginatingMachine;
  #   string   ServiceMachine;
  #   string   ExposedName;
  #   uint32   State;
  #   boolean  Persistent;
  #   boolean  ClientAccessible;
  #   boolean  NoAutoRelease;
  #   boolean  NoWriters;
  #   boolean  Transportable;
  #   boolean  NotSurfaced;
  #   boolean  HardwareAssisted;
  #   boolean  Differential;
  #   boolean  Plex;
  #   boolean  Imported;
  #   boolean  ExposedRemotely;
  #   boolean  ExposedLocally;
  # };
  class ShadowCopy
    NAME = 'Win32_ShadowCopy'

    attr_reader :caption, :description, :id, :install_date, :name, :set_id,
                :provider_id, :status, :count, :device_object, :volume_name,
                :originating_machine, :service_machine, :exposed_name, :state,
                :persistent, :client_accessible, :no_auto_release, :no_writers,
                :transportable, :not_surfaced, :hardware_assisted,
                :differential, :plex, :imported, :exposed_remotely,
                :exposed_locally

    def initialize(obj)
      @caption = obj.Caption
      @description = obj.Description
      @id = obj.ID
      @install_date = Datetime.parse_wmi_datetime(obj.InstallDate)
      @name = obj.Name
      @set_id = obj.SetID
      @provider_id = obj.ProviderID
      @status = obj.Status
      @count = obj.Count
      @device_object = obj.DeviceObject
      @volume_name = obj.VolumeName
      @originating_machine = obj.OriginatingMachine
      @service_machine = obj.ServiceMachine
      @exposed_name = obj.ExposedName
      @state = obj.State
      @persistent = obj.Persistent
      @client_accessible = obj.ClientAccessible
      @no_auto_release = obj.NoAutoRelease
      @no_writers = obj.NoWriters
      @transportable = obj.Transportable
      @not_surfaced = obj.NotSurfaced
      @hardware_assisted = obj.HardwareAssisted
      @differntial = obj.Differential
      @plex = obj.Plex
      @imported = obj.Imported
      @exposed_remotely = obj.ExposedRemotely
      @exposed_locally = obj.ExposedLocally
    end

    def ==(other)
      id == other.id
    end

    def eql?(other)
      self == other
    end

    def hash
      id.hash
    end
  end

  # https://learn.microsoft.com/ja-jp/previous-versions/windows/desktop/legacy/aa394433(v=vs.85)
  # class Win32_ShadowStorage
  # {
  #   uint64           AllocatedSpace;
  #   Win32_Volume REF DiffVolume;
  #   uint64           MaxSpace;
  #   uint64           UsedSpace;
  #   Win32_Volume REF Volume;
  # };
  class ShadowStorage
    NAME = 'Win32_ShadowStorage'

    attr_reader :allocated_space, :diff_volume, :max_space, :used_space, :volume

    def initialize(obj)
      @allocated_space = obj.AllocatedSpace.to_i
      @diff_volume = parse_win32_volume_ref(obj.DiffVolume)
      @max_space = obj.MaxSpace.to_i
      @used_space = obj.UsedSpace.to_i
      @volume = parse_win32_volume_ref(obj.Volume)
    end

    def parse_win32_volume_ref(str)
      m = /^Win32_Volume\.DeviceID="([^"]*)"$/.match(str)

      raise "invalid Win32_Volume REF: #{str}" unless m

      m[1].gsub(/\\{2}/, '\\')
    end
  end

  # https://learn.microsoft.com/en-us/previous-versions/windows/desktop/legacy/aa394515(v=vs.85)
  # class Win32_Volume : CIM_StorageVolume
  # {
  #   uint16   Access;
  #   boolean  Automount;
  #   uint16   Availability;
  #   uint64   BlockSize;
  #   uint64   Capacity;
  #   string   Caption;
  #   boolean  Compressed;
  #   uint32   ConfigManagerErrorCode;
  #   boolean  ConfigManagerUserConfig;
  #   string   CreationClassName;
  #   string   Description;
  #   string   DeviceID;
  #   boolean  DirtyBitSet;
  #   string   DriveLetter;
  #   uint32   DriveType;
  #   boolean  ErrorCleared;
  #   string   ErrorDescription;
  #   string   ErrorMethodology;
  #   string   FileSystem;
  #   uint64   FreeSpace;
  #   boolean  IndexingEnabled;
  #   datetime InstallDate;
  #   string   Label;
  #   uint32   LastErrorCode;
  #   uint32   MaximumFileNameLength;
  #   string   Name;
  #   uint64   NumberOfBlocks;
  #   string   PNPDeviceID;
  #   uint16[] PowerManagementCapabilities;
  #   boolean  PowerManagementSupported;
  #   string   Purpose;
  #   boolean  QuotasEnabled;
  #   boolean  QuotasIncomplete;
  #   boolean  QuotasRebuilding;
  #   string   Status;
  #   uint16   StatusInfo;
  #   string   SystemCreationClassName;
  #   string   SystemName;
  #   uint32   SerialNumber;
  #   boolean  SupportsDiskQuotas;
  #   boolean  SupportsFileBasedCompression;
  # };
  class Volume
    NAME = 'Win32_Volume'

    attr_reader :access, :automount, :availability, :block_size, :capacity,
                :caption, :compressed, :config_manager_error_code,
                :config_manager_user_config, :creation_class_name, :description,
                :device_id, :dirty_bit_set, :drive_letter, :drive_type,
                :error_cleared, :error_description, :error_methodology,
                :file_system, :free_space, :indexing_enabled, :install_date,
                :label, :last_error_code, :maximum_file_name_length, :name,
                :number_of_blocks, :pnp_device_id,
                :power_management_capabilities, :power_management_supported,
                :purpose, :quotas_enabled, :quotas_incomplete,
                :quotas_rebuilding, :status, :status_info,
                :system_creation_class_name, :system_name, :serial_number,
                :supports_disk_quotas, :supports_file_based_compression

    def initialize(obj)
      @access = obj.Access
      @automount = obj.Automount
      @availability = obj.Availability
      @block_size = obj.BlockSize.to_i
      @capacity = obj.Capacity.to_i
      @caption = obj.Caption
      @compressed = obj.Compressed
      @config_manager_error_code = obj.ConfigManagerErrorCode
      @config_manager_user_config = obj.ConfigManagerUserConfig
      @creation_class_name = obj.CreationClassName
      @description = obj.Description
      @device_id = obj.DeviceID
      @dirty_bit_set = obj.DirtyBitSet
      @drive_letter = obj.DriveLetter
      @drive_type = obj.DriveType
      @error_cleared = obj.ErrorCleared
      @error_description = obj.ErrorDescription
      @error_methodology = obj.ErrorMethodology
      @file_system = obj.FileSystem
      @free_space = obj.FreeSpace.to_i
      @indexing_enabled = obj.IndexingEnabled
      @install_date = obj.InstallDate
      @label = obj.Label
      @last_error_code = obj.LastErrorCode
      @maximum_file_name_length = obj.MaximumFileNameLength
      @name = obj.Name
      @number_of_blocks = obj.NumberOfBlocks.to_i
      @pnp_device_id = obj.PNPDeviceID
      @power_management_capabilities = obj.PowerManagementCapabilities
      @power_management_supported = obj.PowerManagementSupported
      @purpose = obj.Purpose
      @quotas_enabled = obj.QuotasEnabled
      @quotas_incomplete = obj.QuotasIncomplete
      @quotas_rebuilding = obj.QuotasRebuilding
      @status = obj.Status
      @status_info = obj.StatusInfo
      @system_creation_class_name = obj.SystemCreationClassName
      @system_name = obj.SystemName
      @serial_number = obj.SerialNumber
      @supports_disk_quotas = obj.SupportsDiskQuotas
      @supports_file_based_compression = obj.SupportsFileBasedCompression
    end
  end
  # rubocop: enable Metrics/AbcSize, Metrics/MethodLength
end

class VSS
  attr_reader :drive

  def initialize(drive = 'C:')
    @drive = drive.upcase
    @drive += ':' unless @drive.end_with?(':')

    Wmi.service.ExecQuery('SELECT * FROM Win32_Volume').each do |obj|
      if @drive.casecmp?(obj.DriveLetter)
        @volume = Wmi::Volume.new(obj)
        break
      end
    end
    raise "No volume mapped by the drive letter: #{@drive}" unless @volume

    Wmi.service.ExecQuery('SELECT * FROM Win32_ShadowStorage').each do |obj|
      ss = Wmi::ShadowStorage.new(obj)
      if @volume.device_id.casecmp?(ss.volume)
        @shadow_storage = ss
        break
      end
    end
    return if @shadow_storage

    raise "Not setup shadow storage: (#{@drive})#{@volume}"
  end

  def capacity
    @volume.capacity
  end

  def free_space
    @volume.free_space
  end

  def shadow_allocated_space
    @shadow_storage.allocated_space
  end

  def shadow_max_space
    @shadow_storage.max_space
  end

  def shadow_used_space
    @shadow_storage.used_space
  end

  def list
    data = []
    Wmi.service.ExecQuery('SELECT * FROM Win32_ShadowCopy').each do |obj|
      sc = Wmi::ShadowCopy.new(obj)
      data << sc if @volume.device_id.casecmp?(sc.volume_name)
    end
    data
  end

  def create
    id = String.new
    obj = Wmi.service.Get('Win32_ShadowCopy')
    obj.Create(@volume, 'ClientAccessible', id)
    id
  end

  def delete(id)
    query = "SELECT * FROM Win32_ShadowCopy WHERE ID = \"#{id}\""
    # rubocop: disable Lint/UnreachableLoop
    Wmi.service.ExecQuery(query).each do |obj|
      sc = Wmi::ShadowCopy.new(obj)
      obj.Delete_
      return sc
    end
    # rubocop: enable Lint/UnreachableLoop
    nil
  end
end

class SchedVSS
  def initialize(mail:, drive:, keep: {}, threshold: {},
                 logger: Logger.new($stderr))
    @time = Time.now
    @vss = VSS.new(drive)

    @mail = mail
    @keep = keep
    @threshold = threshold
    @logger = logger

    @deleted_count = 0
  end

  attr_reader :deleted_count

  def space
    @space ||= {
      capacity: @vss.capacity,
      free: @vss.free_space,
      shadow: {
        max: @vss.shadow_max_space,
        allocated: @vss.shadow_allocated_space,
        used: @vss.shadow_used_space,
      },
    }
  end

  SCHEDULES = [
    {name: :yearly, format: '%Y'},
    {name: :monthly, format: '%Y-%m'},
    {name: :weekly, format: '%G-W%V'},
    {name: :daily, format: '%F'},
    {name: :hourly, format: '%FT%H'},
  ].freeze

  def generation
    return @generation if @generation

    @generation = {}
    list = @vss.list.dup
    SCHEDULES.each do |sched|
      name = sched[:name]
      format = sched[:format]
      limit = @keep[name]
      next unless limit&.positive?

      @generation[name] = take_freq(list, format, limit)
      list -= @generation[name]
    end
    @generation[:delete] = list
    @generation
  end

  def take_freq(list, format, limit)
    freq = {}
    list.sort_by(&:install_date).each do |sc|
      key = sc.install_date.strftime(format)
      next if freq.key?(key)

      freq[key] = sc
      limit -= 1
      break unless limit.positive?
    end
    freq.values
  end

  def data
    {
      time: @time,
      drive: @vss.drive,
      space:,
      generation: generation.transform_values(&:size),
    }
  end

  def usage
    @usage ||= {
      volume: (space[:capacity] - space[:free]).fdiv(space[:capacity]),
      shadow: space[:shadow][:used].fdiv(
        [space[:shadow][:max], space[:capacity]].min),
    }
  end

  def delete_generation
    generation[:delete].each do |sc|
      @logger.info("Delete shadow copy: #{sc.install_date.iso8601}")
      @deleted_count += 1 if @vss.delete(sc.id)
    end
    @deleted_count
  end

  def threshold_over
    [:volume, :shadow].any? do |name|
      @threshold[name]&.<(usage[name])
    end
  end

  def send_mail
    msg = "#{mail_header}\n#{mail_body}"

    @logger.info('Send mail')
    Net::SMTP.start(@mail.dig(:smtp, :server),
                    @mail.dig(:smtp, :port) || 25) do |smtp|
      smtp.send_message(msg, @mail[:from], @mail[:to])
    end
  end

  def mail_header
    <<~MAIL_HEADER
      From: #{@mail[:from]}
      To: #{@mail[:to]}
      Subject: #{if threshold_over
                   '[WARNING] '
                 end}Sched VSS - #{Socket.gethostname}
    MAIL_HEADER
  end

  def mail_body
    <<~MAIL_BODY
      Sched VSS -  Scheduling Volume Shadow Copy
      #{'!!!! EXCEEDING THRESHOLD !!!!' if threshold_over}

      Delete Shadow Copy: #{deleted_count}
      Volume Usage: #{'%.1f' % (usage[:volume] * 100)}%
      Shadow Usage: #{'%.1f' % (usage[:shadow] * 100)}%
      #{data.to_yaml}
    MAIL_BODY
  end
end

def root_path(path)
  File.expand_path(path, __dir__)
end

if $0 == __FILE__
  logger = nil
  begin
    conf_file = root_path('sched_vss.yml')
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

    log_file = root_path(conf.dig(:log, :file) || 'sched_vss.log')
    logger = Logger.new(log_file,
                        conf.dig(:log, :age) || 1,
                        conf.dig(:log, :size) || 1048576,
                        level: conf.dig(:log, :level) || Logger::Severity::INFO,
                        progname: 'sched_vss')
    data_file = root_path(conf[:data_file] || 'sched_vss.jsonl')
    sv = SchedVSS.new(**conf.slice(:mail, :drive, :keep, :threshold), logger:)
    File.open(data_file, 'ab') do |io|
      io.puts sv.data.to_json
    end
    sv.delete_generation
    sv.send_mail
  rescue StandardError => e
    logger&.error(e.full_message(higlight: false))
    raise
  end
end
