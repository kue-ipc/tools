# Ruby version >= 3.0
unless RUBY_VERSION.split('.').first.to_i >= 3
  raise "Require Ruby 3.0 or higher, but RUBY_VERSION = #{RUBY_VERSION}"
end

require 'fiddle/import'
require 'fiddle/types'

module LogManager
  module Utils
    # rubocop: disable Naming
    module WinKernel32
      extend Fiddle::Importer
      dlload 'kernel32.dll'

      # typedef

      # https://learn.microsoft.com/en-us/windows/win32/winprog/windows-data-types
      include Fiddle::Win32Types
      typealias 'LONG', 'long'
      typealias 'ULONGLONG', 'uint64_t' # unsigned __int64
      typealias 'LPVOID', 'void *'
      typealias 'WCHAR', 'wchar_t'
      typealias 'LPWSTR', 'WCHAR *'
      typealias 'LPCWSTR', 'const WCHAR *'
      typealias 'HRESULT', 'LONG'

      # https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-ularge_integer-r1
      typealias 'ULARGE_INTEGER', 'ULONGLONG' # union
      typealias 'PULARGE_INTEGER', 'ULARGE_INTEGER *'

      # enum

      # https://learn.microsoft.com/en-us/windows/win32/api/minwinbase/ne-minwinbase-get_fileex_info_levels
      typealias 'GET_FILEEX_INFO_LEVELS', 'int' # enum
      GetFileExInfoStandard = 0
      GetFileExMaxInfoLevel = 1

      # constant

      FALSE = 0
      TRUE = 1

      # https://learn.microsoft.com/en-us/windows/win32/fileio/file-attribute-constants
      FILE_ATTRIBUTE_READONLY              = 0x00000001
      FILE_ATTRIBUTE_HIDDEN                = 0x00000002
      FILE_ATTRIBUTE_SYSTEM                = 0x00000004
      FILE_ATTRIBUTE_DIRECTORY             = 0x00000010
      FILE_ATTRIBUTE_ARCHIVE               = 0x00000020
      FILE_ATTRIBUTE_DEVICE                = 0x00000040
      FILE_ATTRIBUTE_NORMAL                = 0x00000080
      FILE_ATTRIBUTE_TEMPORARY             = 0x00000100
      FILE_ATTRIBUTE_SPARSE_FILE           = 0x00000200
      FILE_ATTRIBUTE_REPARSE_POINT         = 0x00000400
      FILE_ATTRIBUTE_COMPRESSED            = 0x00000800
      FILE_ATTRIBUTE_OFFLINE               = 0x00001000
      FILE_ATTRIBUTE_NOT_CONTENT_INDEXED   = 0x00002000
      FILE_ATTRIBUTE_ENCRYPTED             = 0x00004000
      FILE_ATTRIBUTE_INTEGRITY_STREAM      = 0x00008000
      FILE_ATTRIBUTE_VIRTUAL               = 0x00010000
      FILE_ATTRIBUTE_NO_SCRUB_DATA         = 0x00020000
      FILE_ATTRIBUTE_EA                    = 0x00040000
      FILE_ATTRIBUTE_PINNED                = 0x00080000
      FILE_ATTRIBUTE_UNPINNED              = 0x00100000
      FILE_ATTRIBUTE_RECALL_ON_OPEN        = 0x00040000
      FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = 0x00400000

      # struct

      # https://learn.microsoft.com/en-us/windows/win32/api/minwinbase/ns-minwinbase-filetime
      Filetime = struct([
        'DWORD dwLowDateTime',
        'DWORD dwHighDateTime',
      ])

      # https://learn.microsoft.com/en-us/windows/win32/api/fileapi/ns-fileapi-win32_file_attribute_data

      FileAttributeData = struct([
        'DWORD dwFileAttributes',
        {ftCreationTime: Filetime},
        {ftLastAccessTime: Filetime},
        {ftLastWriteTime: Filetime},
        'DWORD nFileSizeHigh',
        'DWORD nFileSizeLow',
      ])

      # https://learn.microsoft.com/en-us/windows/win32/api/fileapi/ns-fileapi-disk_space_information
      DiskSpaceInformation = struct([
        'ULONGLONG ActualTotalAllocationUnits',
        'ULONGLONG ActualAvailableAllocationUnits',
        'ULONGLONG ActualPoolUnavailableAllocationUnits',
        'ULONGLONG CallerTotalAllocationUnits',
        'ULONGLONG CallerAvailableAllocationUnits',
        'ULONGLONG CallerPoolUnavailableAllocationUnits',
        'ULONGLONG UsedAllocationUnits',
        'ULONGLONG TotalReservedAllocationUnits',
        'ULONGLONG VolumeStorageReserveAllocationUnits',
        'ULONGLONG AvailableCommittedAllocationUnits',
        'ULONGLONG PoolAvailableAllocationUnits',
        'DWORD SectorsPerAllocationUnit',
        'DWORD BytesPerSector',
      ])

      # macro

      # https://learn.microsoft.com/en-us/windows/win32/api/winerror/nf-winerror-succeeded
      def self.SUCCEEDED(hr)
        hr >= 0
      end

      # https://learn.microsoft.com/en-us/windows/win32/api/winerror/nf-winerror-failed
      def self.FAILED(hr)
        hr < 0 # rubocop: disable Style/NumericPredicate
      end

      # funciton

      # https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfileattributesexw
      extern 'BOOL GetFileAttributesExW(LPCWSTR, GET_FILEEX_INFO_LEVELS, ' \
             'LPVOID)'

      # https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getdiskfreespaceexw
      extern 'BOOL GetDiskFreeSpaceExW(LPCWSTR, ' \
             'PULARGE_INTEGER, PULARGE_INTEGER, PULARGE_INTEGER)'

      # https://learn.microsoft.com/ja-jp/windows/win32/api/fileapi/nf-fileapi-getvolumepathnamew
      extern 'BOOL GetVolumePathNameW(LPCWSTR, LPWSTR, DWORD)'

      # https://learn.microsoft.com/ja-jp/windows/win32/api/fileapi/nf-fileapi-getdiskspaceinformationw
      extern 'HRESULT GetDiskSpaceInformationW(LPCWSTR, void *)'
    end
    # rubocop: enable Naming
  end
end
