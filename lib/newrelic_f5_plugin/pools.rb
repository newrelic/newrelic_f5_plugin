#!/usr/bin/env ruby

require 'newrelic_plugin'

#  LtmPoolStatEntry
#    ltmPoolStatName                                        LongDisplayString,
#    ltmPoolStatServerPktsIn                                Counter64,
#    ltmPoolStatServerBytesIn                               Counter64,
#    ltmPoolStatServerPktsOut                               Counter64,
#    ltmPoolStatServerBytesOut                              Counter64,
#    ltmPoolStatServerMaxConns                              Counter64,
#    ltmPoolStatServerTotConns                              Counter64,
#    ltmPoolStatServerCurConns                              CounterBasedGauge64,
#    ltmPoolStatPvaPktsIn                                   Counter64,
#    ltmPoolStatPvaBytesIn                                  Counter64,
#    ltmPoolStatPvaPktsOut                                  Counter64,
#    ltmPoolStatPvaBytesOut                                 Counter64,
#    ltmPoolStatPvaMaxConns                                 Counter64,
#    ltmPoolStatPvaTotConns                                 Counter64,
#    ltmPoolStatPvaCurConns                                 CounterBasedGauge64,
#    ltmPoolStatTotPvaAssistConn                            Counter64,
#    ltmPoolStatCurrPvaAssistConn                           CounterBasedGauge64,
#    ltmPoolStatConnqDepth                                  Integer32,
#    ltmPoolStatConnqAgeHead                                Integer32,
#    ltmPoolStatConnqAgeMax                                 Integer32,
#    ltmPoolStatConnqAgeEma                                 Integer32,
#    ltmPoolStatConnqAgeEdm                                 Integer32,
#    ltmPoolStatConnqServiced                               Counter64,
#    ltmPoolStatConnqAllDepth                               Integer32,
#    ltmPoolStatConnqAllAgeHead                             Integer32,
#    ltmPoolStatConnqAllAgeMax                              Integer32,
#    ltmPoolStatConnqAllAgeEma                              Integer32,
#    ltmPoolStatConnqAllAgeEdm                              Integer32,
#    ltmPoolStatConnqAllServiced                            Counter64,
#    ltmPoolStatTotRequests                                 Counter64,
#    ltmPoolStatCurSessions                                 CounterBasedGauge64


module NewRelic
  module F5Plugin

    class Pools
      attr_accessor :pool_names, :snmp_manager

      OID_LTM_POOLS                      = "1.3.6.1.4.1.3375.2.2.5"
      OID_LTM_POOL_STAT                  = "#{OID_LTM_POOLS}.2"
      OID_LTM_POOL_ENTRY                 = "#{OID_LTM_POOL_STAT}.3.1"
      OID_LTM_POOL_STAT_NAME             = "#{OID_LTM_POOL_ENTRY}.1"
      OID_LTM_POOL_STAT_SERVER_BYTES_IN  = "#{OID_LTM_POOL_ENTRY}.3"
      OID_LTM_POOL_STAT_SERVER_BYTES_OUT = "#{OID_LTM_POOL_ENTRY}.5"
      OID_LTM_POOL_STAT_SERVER_TOT_CONNS = "#{OID_LTM_POOL_ENTRY}.7"
      OID_LTM_POOL_STAT_SERVER_CUR_CONNS = "#{OID_LTM_POOL_ENTRY}.8"
      OID_LTM_POOL_STAT_TOT_REQUESTS     = "#{OID_LTM_POOL_ENTRY}.30"



      #
      # Init
      #
      def initialize(snmp = nil)
        @pool_names = [ ]

        if snmp
          @snmp_manager = snmp
        else
          @snmp_manager = nil
        end
      end



      #
      # Get the list of Pool names
      #
      def get_names(snmp = nil)
        snmp = snmp_manager unless snmp

        if snmp
          @pool_names.clear

          begin
            snmp.walk([OID_LTM_POOL_STAT_NAME]) do |row|
              row.each do |vb|
                @pool_names.push(vb.value)
              end
            end
          rescue Exception => e
            NewRelic::PlatformLogger.error("Unable to gather Pool names with error: #{e}")
          end

          NewRelic::PlatformLogger.debug("Pools: Found #{@pool_names.size} pools")
          return @pool_names
        end
      end



      #
      # Gather Total Requests
      #
      def get_requests(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @pool_names.empty?
        res = gather_snmp_metrics_by_name("Pools/Requests", @pool_names, OID_LTM_POOL_STAT_TOT_REQUESTS, snmp)
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@pool_names.size} Request metrics")
        return res
      end



      #
      # Gather Connection count
      #
      def get_conns_current(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @pool_names.empty?
        res = gather_snmp_metrics_by_name("Pools/Current Connections", @pool_names, OID_LTM_POOL_STAT_SERVER_CUR_CONNS, snmp)
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@pool_names.size} Current Connection metrics")
        return res
      end



      #
      # Gather Connection rate
      #
      def get_conns_total(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @pool_names.empty?
        res = gather_snmp_metrics_by_name("Pools/Connection Rate", @pool_names, OID_LTM_POOL_STAT_SERVER_TOT_CONNS, snmp)
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@pool_names.size} Connection Rate metrics")
        return res
      end



      #
      # Gather Throughput Inbound (returns in bits)
      #
      def get_throughput_in(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @pool_names.empty?
        res = gather_snmp_metrics_by_name("Pools/Throughput/In", @pool_names, OID_LTM_POOL_STAT_SERVER_BYTES_IN, snmp)
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@pool_names.size} Inbound Throughput metrics")
        return res
      end



      #
      # Gather Throughput Inbound (returns in bits)
      #
      def get_throughput_out(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @pool_names.empty?
        res = gather_snmp_metrics_by_name("Pools/Throughput/Out", @pool_names, OID_LTM_POOL_STAT_SERVER_BYTES_OUT, snmp)
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@pool_names.size} Outbound Throughput metrics")
        return res
      end

    end
  end
end

