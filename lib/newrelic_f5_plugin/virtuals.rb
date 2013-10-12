#!/usr/bin/env ruby

require 'newrelic_plugin'

#LtmVirtualServStatEntry
#  ltmVirtualServStatName                                 LongDisplayString,
#  ltmVirtualServStatCsMinConnDur                         Counter64,
#  ltmVirtualServStatCsMaxConnDur                         Counter64,
#  ltmVirtualServStatCsMeanConnDur                        Counter64,
#  ltmVirtualServStatNoNodesErrors                        Counter64,
#  ltmVirtualServStatClientPktsIn                         Counter64,
#  ltmVirtualServStatClientBytesIn                        Counter64,
#  ltmVirtualServStatClientPktsOut                        Counter64,
#  ltmVirtualServStatClientBytesOut                       Counter64,
#  ltmVirtualServStatClientMaxConns                       Counter64,
#  ltmVirtualServStatClientTotConns                       Counter64,
#  ltmVirtualServStatClientCurConns                       CounterBasedGauge64,
#  ltmVirtualServStatEphemeralPktsIn                      Counter64,
#  ltmVirtualServStatEphemeralBytesIn                     Counter64,
#  ltmVirtualServStatEphemeralPktsOut                     Counter64,
#  ltmVirtualServStatEphemeralBytesOut                    Counter64,
#  ltmVirtualServStatEphemeralMaxConns                    Counter64,
#  ltmVirtualServStatEphemeralTotConns                    Counter64,
#  ltmVirtualServStatEphemeralCurConns                    CounterBasedGauge64,
#  ltmVirtualServStatPvaPktsIn                            Counter64,
#  ltmVirtualServStatPvaBytesIn                           Counter64,
#  ltmVirtualServStatPvaPktsOut                           Counter64,
#  ltmVirtualServStatPvaBytesOut                          Counter64,
#  ltmVirtualServStatPvaMaxConns                          Counter64,
#  ltmVirtualServStatPvaTotConns                          Counter64,
#  ltmVirtualServStatPvaCurConns                          CounterBasedGauge64,
#  ltmVirtualServStatTotRequests                          Counter64,
#  ltmVirtualServStatTotPvaAssistConn                     Counter64,
#  ltmVirtualServStatCurrPvaAssistConn                    CounterBasedGauge64,
#  ltmVirtualServStatCycleCount                           Counter64,
#  ltmVirtualServStatVsUsageRatio5s                       Gauge,
#  ltmVirtualServStatVsUsageRatio1m                       Gauge,
#  ltmVirtualServStatVsUsageRatio5m                       Gauge


module NewRelic
  module F5Plugin

    class Virtuals
      attr_accessor :vs_names, :snmp_manager

      OID_LTM_VIRTUAL_SERVERS     = "1.3.6.1.4.1.3375.2.2.10"

      OID_LTM_VIRTUAL_SERV_STAT                   = "#{OID_LTM_VIRTUAL_SERVERS}.2"
      OID_LTM_VIRTUAL_SERV_ENTRY                  = "#{OID_LTM_VIRTUAL_SERV_STAT}.3.1"
      OID_LTM_VIRTUAL_SERV_STAT_NAME              = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.1"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_IN   = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.7"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_OUT  = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.9"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_TOT_CONNS  = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.11"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_CUR_CONNS  = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.12"
      OID_LTM_VIRTUAL_SERV_STAT_TOT_REQUESTS      = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.27"
      OID_LTM_VIRTUAL_SERV_STAT_VS_USAGE_RATIO_1M = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.32"



      #
      # Init
      #
      def initialize(snmp = nil)
        @vs_names = [ ]

        if snmp
          @snmp_manager = snmp
        else
          @snmp_manager = nil
        end
      end



      #
      # Get the list of Virtual Server names
      #
      def get_names(snmp = nil)
        snmp = snmp_manager unless snmp

        if snmp
          @vs_names.clear

          begin
            snmp.walk([OID_LTM_VIRTUAL_SERV_STAT_NAME]) do |row|
              row.each do |vb|
                @vs_names.push(vb.value)
              end
            end
          rescue Exception => e
            NewRelic::PlatformLogger.error("Unable to gather Virtual Server names with error: #{e}")
          end

          NewRelic::PlatformLogger.debug("Virtual Servers: Found #{@vs_names.size} virtual servers")
          return @vs_names
        end
      end



      #
      # Gather VS Total Requests
      #
      def get_requests(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @vs_names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Requests", @vs_names, OID_LTM_VIRTUAL_SERV_STAT_TOT_REQUESTS, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@vs_names.size} Request metrics")
        return res
      end



      #
      # Gather VS Connection count
      #
      def get_conns_current(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @vs_names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Current Connections", @vs_names, OID_LTM_VIRTUAL_SERV_STAT_CLIENT_CUR_CONNS, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@vs_names.size} Current Connection metrics")
        return res
      end



      #
      # Gather VS Connection rate
      #
      def get_conns_total(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @vs_names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Connection Rate", @vs_names, OID_LTM_VIRTUAL_SERV_STAT_CLIENT_TOT_CONNS, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@vs_names.size} Connection Rate metrics")
        return res
      end



      #
      # Gather VS Throughput Inbound (returns in bits)
      #
      def get_throughput_in(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @vs_names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Throughput/In", @vs_names, OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_IN, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@vs_names.size} Inbound Throughput metrics")
        return res
      end



      #
      # Gather VS Throughput Inbound (returns in bits)
      #
      def get_throughput_out(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @vs_names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Throughput/Out", @vs_names, OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_OUT, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@vs_names.size} Outbound Throughput metrics")
        return res
      end



      #
      # Gather VS Connection rate
      #
      def get_cpu_usage_1m(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @vs_names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/CPU Usage/1m", @vs_names, OID_LTM_VIRTUAL_SERV_STAT_VS_USAGE_RATIO_1M, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@vs_names.size} CPU metrics")
        return res
      end

    end
  end
end

