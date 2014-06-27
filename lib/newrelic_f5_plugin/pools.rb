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
      attr_accessor :names, :snmp_manager

      MAX_RESULTS                        = 100
      OID_LTM_POOLS                      = "1.3.6.1.4.1.3375.2.2.5"
      OID_LTM_POOL_STAT                  = "#{OID_LTM_POOLS}.2"
      OID_LTM_POOL_ENTRY                 = "#{OID_LTM_POOL_STAT}.3.1"
      OID_LTM_POOL_STAT_NAME             = "#{OID_LTM_POOL_ENTRY}.1"
      OID_LTM_POOL_STAT_SERVER_PKTS_IN   = "#{OID_LTM_POOL_ENTRY}.2"
      OID_LTM_POOL_STAT_SERVER_BYTES_IN  = "#{OID_LTM_POOL_ENTRY}.3"
      OID_LTM_POOL_STAT_SERVER_PKTS_OUT  = "#{OID_LTM_POOL_ENTRY}.4"
      OID_LTM_POOL_STAT_SERVER_BYTES_OUT = "#{OID_LTM_POOL_ENTRY}.5"
      OID_LTM_POOL_STAT_SERVER_TOT_CONNS = "#{OID_LTM_POOL_ENTRY}.7"
      OID_LTM_POOL_STAT_SERVER_CUR_CONNS = "#{OID_LTM_POOL_ENTRY}.8"
      OID_LTM_POOL_STAT_TOT_REQUESTS     = "#{OID_LTM_POOL_ENTRY}.30"



      #
      # Init
      #
      def initialize(snmp = nil)
        @names    = [ ]
        @f5_agent = nil

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
        @f5_agent     = agent

        unless get_names.empty?
          get_requests
          get_conns_current
          get_conns_total
          get_packets_in
          get_packets_out
          get_throughput_in
          get_throughput_out
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
            snmp.walk([OID_LTM_POOL_STAT_NAME]) do |row|
              row.each do |vb|
                @names.push(vb.value)
              end
            end
          rescue Exception => e
            NewRelic::PlatformLogger.error("Unable to gather Pool names with error: #{e}")
          end

          NewRelic::PlatformLogger.debug("Pools: Found #{@names.size} pools, reporting the top #{MAX_RESULTS} (max)")
          return @names
        end
      end



      #
      # Gather Total Requests
      #
      def get_requests(snmp = nil)
        @req_rate ||= { }
        report      = { }
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Pools/Requests", @names, OID_LTM_POOL_STAT_TOT_REQUESTS, snmp)
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@names.size} Request metrics")

        unless res.nil?
          res.each_key do |metric|
            @req_rate[metric] ||= NewRelic::Processor::EpochCounter.new
            report[metric] = @req_rate[metric].process(res[metric])
          end

          sorted_report = report.sort_by { |k,v| v }.reverse
          sorted_report.each_with_index do |row, index|
            @f5_agent.report_metric row[0], "req/sec", row[1]
            break if index >= (MAX_RESULTS - 1)
          end
        end
      end



      #
      # Gather Connection count
      #
      def get_conns_current(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Pools/Current Connections", @names, OID_LTM_POOL_STAT_SERVER_CUR_CONNS, snmp)
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@names.size} Current Connection metrics")

        unless res.nil?
          sorted_report = res.sort_by { |k,v| v }.reverse
          sorted_report.each_with_index do |row, index|
            @f5_agent.report_metric row[0], "conns", row[1]
            break if index >= (MAX_RESULTS - 1)
          end
        end
      end



      #
      # Gather Connection rate
      #
      def get_conns_total(snmp = nil)
        @conn_rate ||= { }
        report       = { }
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Pools/Connection Rate", @names, OID_LTM_POOL_STAT_SERVER_TOT_CONNS, snmp)
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@names.size} Connection Rate metrics")

        unless res.nil?
          res.each_key do |metric|
            @conn_rate[metric] ||= NewRelic::Processor::EpochCounter.new
            report[metric] = @conn_rate[metric].process(res[metric])
          end

          sorted_report = report.sort_by { |k,v| v }.reverse
          sorted_report.each_with_index do |row, index|
            @f5_agent.report_metric row[0], "conn/sec", row[1]
            break if index >= (MAX_RESULTS - 1)
          end
        end
      end



      #
      # Gather Packets Inbound
      #
      def get_packets_in(snmp = nil)
        @packet_in_rate ||= { }
        report            = { }
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Pools/Packets/In", @names, OID_LTM_POOL_STAT_SERVER_PKTS_IN, snmp)
        res = res.each_key { |n| res[n] *= 8 }
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@names.size} Inbound Packet metrics")

        unless res.nil?
          res.each_key do |metric|
            @packet_in_rate[metric] ||= NewRelic::Processor::EpochCounter.new
            report[metric] = @packet_in_rate[metric].process(res[metric] * 8)
          end

          sorted_report = report.sort_by { |k,v| v }.reverse
          sorted_report.each_with_index do |row, index|
            @f5_agent.report_metric row[0], "packets/sec", row[1]
            break if index >= (MAX_RESULTS - 1)
          end
        end
      end



      #
      # Gather Packets Outbound
      #
      def get_packets_out(snmp = nil)
        @packet_out_rate ||= { }
        report             = { }
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Pools/Packets/Out", @names, OID_LTM_POOL_STAT_SERVER_PKTS_OUT, snmp)
        res = res.each_key { |n| res[n] *= 8 }
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@names.size} Outbound Packet metrics")

        unless res.nil?
          res.each_key do |metric|
            @packet_out_rate[metric] ||= NewRelic::Processor::EpochCounter.new
            report[metric] = @packet_out_rate[metric].process(res[metric] * 8)
          end

          sorted_report = report.sort_by { |k,v| v }.reverse
          sorted_report.each_with_index do |row, index|
            @f5_agent.report_metric row[0], "packets/sec", row[1]
            break if index >= (MAX_RESULTS - 1)
          end
        end
      end



      #
      # Gather Throughput Inbound (returns in bits)
      #
      def get_throughput_in(snmp = nil)
        @throughput_in_rate ||= { }
        report                = { }
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Pools/Throughput/In", @names, OID_LTM_POOL_STAT_SERVER_BYTES_IN, snmp)
        res = res.each_key { |n| res[n] *= 8 }
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@names.size} Inbound Throughput metrics")

        unless res.nil?
          res.each_key do |metric|
            @throughput_in_rate[metric] ||= NewRelic::Processor::EpochCounter.new
            report[metric] = @throughput_in_rate[metric].process(res[metric] * 8)
          end

          sorted_report = report.sort_by { |k,v| v }.reverse
          sorted_report.each_with_index do |row, index|
            @f5_agent.report_metric row[0], "bits/sec", row[1]
            break if index >= (MAX_RESULTS - 1)
          end
        end
      end



      #
      # Gather Throughput Outbound (returns in bits)
      #
      def get_throughput_out(snmp = nil)
        @throughput_out_rate ||= { }
        report                 = { }
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Pools/Throughput/Out", @names, OID_LTM_POOL_STAT_SERVER_BYTES_OUT, snmp)
        res = res.each_key { |n| res[n] *= 8 }
        NewRelic::PlatformLogger.debug("Pools: Got #{res.size}/#{@names.size} Outbound Throughput metrics")

        unless res.nil?
          res.each_key do |metric|
            @throughput_out_rate[metric] ||= NewRelic::Processor::EpochCounter.new
            report[metric] = @throughput_out_rate[metric].process(res[metric] * 8)
          end

          sorted_report = report.sort_by { |k,v| v }.reverse
          sorted_report.each_with_index do |row, index|
            @f5_agent.report_metric row[0], "bits/sec", row[1]
            break if index >= (MAX_RESULTS - 1)
          end
        end
      end

    end
  end
end

