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
      attr_accessor :names, :snmp_manager

      MAX_RESULTS                                 = 100
      OID_LTM_VIRTUAL_SERVERS                     = "1.3.6.1.4.1.3375.2.2.10"
      OID_LTM_VIRTUAL_SERV_STAT                   = "#{OID_LTM_VIRTUAL_SERVERS}.2"
      OID_LTM_VIRTUAL_SERV_ENTRY                  = "#{OID_LTM_VIRTUAL_SERV_STAT}.3.1"
      OID_LTM_VIRTUAL_SERV_STAT_NAME              = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.1"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_PKTS_IN    = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.6"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_IN   = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.7"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_PKTS_OUT   = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.8"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_OUT  = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.9"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_TOT_CONNS  = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.11"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_CUR_CONNS  = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.12"
      OID_LTM_VIRTUAL_SERV_STAT_TOT_REQUESTS      = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.27"
      OID_LTM_VIRTUAL_SERV_STAT_VS_USAGE_RATIO_1M = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.32"



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
          get_cpu_usage_1m
        end
      end



      #
      # Get the list of Virtual Server names
      #
      def get_names(snmp = nil)
        snmp = @snmp_manager unless snmp

        if snmp
          @names.clear

          begin
            snmp.walk([OID_LTM_VIRTUAL_SERV_STAT_NAME]) do |row|
              row.each do |vb|
                @names.push(vb.value)
              end
            end
          rescue Exception => e
            NewRelic::PlatformLogger.error("Unable to gather Virtual Server names with error: #{e}")
          end

          NewRelic::PlatformLogger.debug("Virtual Servers: Found #{@names.size} virtual servers, reporting the top #{MAX_RESULTS} max.")
          return @names
        end
      end



      #
      # Gather VS Total Requests
      #
      def get_requests(snmp = nil)
        @req_rate ||= { }
        report      = { }
        snmp        = @snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Requests", @names, OID_LTM_VIRTUAL_SERV_STAT_TOT_REQUESTS, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@names.size} Request metrics")

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
      # Gather VS Connection count
      #
      def get_conns_current(snmp = nil)
        snmp = @snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Current Connections", @names, OID_LTM_VIRTUAL_SERV_STAT_CLIENT_CUR_CONNS, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@names.size} Current Connection metrics")

        unless res.nil?
          sorted_report = res.sort_by { |k,v| v }.reverse
          sorted_report.each_with_index do |row, index|
            @f5_agent.report_metric row[0], "conns", row[1]
            break if index >= (MAX_RESULTS - 1)
          end
        end
      end



      #
      # Gather VS Connection rate
      #
      def get_conns_total(snmp = nil)
        @conn_rate ||= { }
        report       = { }
        snmp         = @snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Connection Rate", @names, OID_LTM_VIRTUAL_SERV_STAT_CLIENT_TOT_CONNS, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@names.size} Connection Rate metrics")

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
      # Gather VS Packets Inbound
      #
      def get_packets_in (snmp = nil)
        @packet_in_rate ||= { }
        report            = { }
        snmp              = @snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Packets/In", @names, OID_LTM_VIRTUAL_SERV_STAT_CLIENT_PKTS_IN, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@names.size} Inbound Packet metrics")

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
      # Gather VS Packets Outbound
      #
      def get_packets_out(snmp = nil)
        @packet_out_rate ||= { }
        report             = { }
        snmp               = @snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Packets/Out", @names, OID_LTM_VIRTUAL_SERV_STAT_CLIENT_PKTS_OUT, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@names.size} Outbound Packet metrics")

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
      # Gather VS Throughput Inbound (returns in bits)
      #
      def get_throughput_in(snmp = nil)
        @throughput_in_rate ||= { }
        report                = { }
        snmp                  = @snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Throughput/In", @names, OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_IN, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@names.size} Inbound Throughput metrics")

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
      # Gather VS Throughput Outbound (returns in bits)
      #
      def get_throughput_out(snmp = nil)
        @throughput_out_rate ||= { }
        report                 = { }
        snmp                   = @snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/Throughput/Out", @names, OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_OUT, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@names.size} Outbound Throughput metrics")

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



      #
      # Gather VS Connection rate
      #
      def get_cpu_usage_1m(snmp = nil)
        snmp = @snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Virtual Servers/CPU Usage/1m", @names, OID_LTM_VIRTUAL_SERV_STAT_VS_USAGE_RATIO_1M, snmp)
        NewRelic::PlatformLogger.debug("Virtual Servers: Got #{res.size}/#{@names.size} CPU metrics")

        unless res.nil?
          sorted_report = res.sort_by { |k,v| v }.reverse
          sorted_report.each_with_index do |row, index|
            @f5_agent.report_metric row[0], "%", row[1]
            break if index >= (MAX_RESULTS - 1)
          end
        end
      end

    end
  end
end

