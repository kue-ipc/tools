require 'win32ole'

module Wmi
  def self.service
    @service ||=
      WIN32OLE.new('WbemScripting.SWbemLocator')
        .ConnectServer('.', 'root/cimv2')
  end

  def self.each_event(wql, &)
    return to_enum(__method__, wql) unless block_given?

    eventset = self.service.ExecQuery(wql)
    eventset.each(&)
  end
end
