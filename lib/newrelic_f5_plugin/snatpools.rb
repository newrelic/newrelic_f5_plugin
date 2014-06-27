#!/usr/bin/env ruby

require 'newrelic_plugin'

#LtmSnatPoolStatEntry
#    ltmSnatPoolStatName                                    LongDisplayString,
#    ltmSnatPoolStatServerPktsIn                            Counter64,
#    ltmSnatPoolStatServerBytesIn                           Counter64,
#    ltmSnatPoolStatServerPktsOut                           Counter64,
#    ltmSnatPoolStatServerBytesOut                          Counter64,
#    ltmSnatPoolStatServerMaxConns                          Counter64,
#    ltmSnatPoolStatServerTotConns                          Counter64,
#    ltmSnatPoolStatServerCurConns                          CounterBasedGauge64


module NewRelic
  module F5Plugin

    class SnatPools
      attr_accessor :names, :snmp_manager

      OID_LTM_SNATS                      = "1.3.6.1.4.1.3375.2.2.9"
      OID_LTM_SNAT_POOL                  = "#{OID_LTM_SNATS}.7"
      OID_LTM_SNAT_POOL_ENTRY            = "#{OID_LTM_SNAT_POOL}.2.1"

      OID_LTM_SNAT_POOL_STAT             = "#{OID_LTM_SNATS}.8"
      OID_LTM_SNAT_POOL_STAT_ENTRY       = "#{OID_LTM_SNAT_POOL_STAT}.3.1"

      OID_LTM_SNAT_POOL_STAT_NAME             = "#{OID_LTM_SNAT_POOL_STAT_ENTRY}.1"
      OID_LTM_SNAT_POOL_STAT_SERVER_PKTS_IN   = "#{OID_LTM_SNAT_POOL_STAT_ENTRY}.2"
      OID_LTM_SNAT_POOL_STAT_SERVER_BYTES_IN  = "#{OID_LTM_SNAT_POOL_STAT_ENTRY}.3"
      OID_LTM_SNAT_POOL_STAT_SERVER_PKTS_OUT  = "#{OID_LTM_SNAT_POOL_STAT_ENTRY}.4"
      OID_LTM_SNAT_POOL_STAT_SERVER_BYTES_OUT = "#{OID_LTM_SNAT_POOL_STAT_ENTRY}.5"
      OID_LTM_SNAT_POOL_STAT_SERVER_MAX_CONNS = "#{OID_LTM_SNAT_POOL_STAT_ENTRY}.6"
      OID_LTM_SNAT_POOL_STAT_SERVER_TOT_CONNS = "#{OID_LTM_SNAT_POOL_STAT_ENTRY}.7"
      OID_LTM_SNAT_POOL_STAT_SERVER_CUR_CONNS = "#{OID_LTM_SNAT_POOL_STAT_ENTRY}.8"



      #
      # Init
      #
      def initialize(snmp = nil)
        @names = [ ]

        if snmp
          @snmp_manager = snmp
        else
          @snmp_manager = nil
        end
      end



      #
      # Perform polling and reportings of metrics
      #
      def poll(agent, snmp)
        @snmp_manager = snmp

        unless get_names.empty?
          snatpool_conns_max = get_conns_max
          snatpool_conns_max.each_key { |m| agent.report_metric m, "conns", snatpool_conns_max[m] } unless snatpool_conns_max.nil?

          snatpool_conns_current = get_conns_current
          snatpool_conns_current.each_key { |m| agent.report_metric m, "conns", snatpool_conns_current[m] } unless snatpool_conns_current.nil?

          snatpool_conns_total = get_conns_total
          snatpool_conns_total.each_key { |m| agent.report_counter_metric m, "conn/sec", snatpool_conns_total[m] } unless snatpool_conns_total.nil?

          snatpool_throughput_in = get_throughput_in
          snatpool_throughput_in.each_key { |m| agent.report_counter_metric m, "bits/sec", snatpool_throughput_in[m] } unless snatpool_throughput_in.nil?

          snatpool_throughput_out = get_throughput_out
          snatpool_throughput_out.each_key { |m| agent.report_counter_metric m, "bits/sec", snatpool_throughput_out[m] } unless snatpool_throughput_out.nil?

          snatpool_packets_in = get_packets_in
          snatpool_packets_in.each_key { |m| agent.report_counter_metric m, "pkts/sec", snatpool_packets_in[m] } unless snatpool_packets_in.nil?

          snatpool_packets_out = get_packets_out
          snatpool_packets_out.each_key { |m| agent.report_counter_metric m, "pkts/sec", snatpool_packets_out[m] } unless snatpool_packets_out.nil?
        end
      end



      #
      # Get the list of Pool names
      #
      def get_names(snmp = nil)
        snmp = snmp_manager unless snmp

        if snmp
          @names.clear

          begin
            snmp.walk([OID_LTM_SNAT_POOL_STAT_NAME]) do |row|
              row.each do |vb|
                @names.push(vb.value)
              end
            end
          rescue Exception => e
            NewRelic::PlatformLogger.error("Unable to gather SNAT Pool names with error: #{e}")
          end

          NewRelic::PlatformLogger.debug("SNAT Pools: Found #{@names.size} pools")
          return @names
        end
      end



      #
      # Gather Max Connection count
      #
      def get_conns_max(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("SnatPools/Max Connections", @names, OID_LTM_SNAT_POOL_STAT_SERVER_MAX_CONNS, snmp)
        NewRelic::PlatformLogger.debug("SNAT Pools: Got #{res.size}/#{@names.size} Max Connection metrics")
        return res
      end



      #
      # Gather Connection count
      #
      def get_conns_current(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("SnatPools/Current Connections", @names, OID_LTM_SNAT_POOL_STAT_SERVER_CUR_CONNS, snmp)
        NewRelic::PlatformLogger.debug("SNAT Pools: Got #{res.size}/#{@names.size} Current Connection metrics")
        return res
      end



      #
      # Gather Connection rate
      #
      def get_conns_total(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("SnatPools/Connection Rate", @names, OID_LTM_SNAT_POOL_STAT_SERVER_TOT_CONNS, snmp)
        NewRelic::PlatformLogger.debug("SNAT Pools: Got #{res.size}/#{@names.size} Connection Rate metrics")
        return res
      end



      #
      # Gather Throughput Inbound (returns in bits)
      #
      def get_throughput_in(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("SnatPools/Throughput/In", @names, OID_LTM_SNAT_POOL_STAT_SERVER_BYTES_IN, snmp)
        res = res.each_key { |n| res[n] *= 8 }
        NewRelic::PlatformLogger.debug("SNAT Pools: Got #{res.size}/#{@names.size} Inbound Throughput metrics")
        return res
      end



      #
      # Gather Throughput Inbound (returns in bits)
      #
      def get_throughput_out(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("SnatPools/Throughput/Out", @names, OID_LTM_SNAT_POOL_STAT_SERVER_BYTES_OUT, snmp)
        res = res.each_key { |n| res[n] *= 8 }
        NewRelic::PlatformLogger.debug("SNAT Pools: Got #{res.size}/#{@names.size} Outbound Throughput metrics")
        return res
      end



      #
      # Gather Packets Inbound
      #
      def get_packets_in(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("SnatPools/Packets/In", @names, OID_LTM_SNAT_POOL_STAT_SERVER_PKTS_IN, snmp)
        NewRelic::PlatformLogger.debug("SNAT Pools: Got #{res.size}/#{@names.size} Inbound packet metrics")
        return res
      end



      #
      # Gather Packets Outbound
      #
      def get_packets_out(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("SnatPools/Packets/Out", @names, OID_LTM_SNAT_POOL_STAT_SERVER_PKTS_OUT, snmp)
        NewRelic::PlatformLogger.debug("SNAT Pools: Got #{res.size}/#{@names.size} Outbound packet metrics")
        return res
      end

    end
  end
end

