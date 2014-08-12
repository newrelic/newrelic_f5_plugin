#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'

# sysInterfaceEntry
#    sysInterfaceName                                       LongDisplayString,
#    sysInterfaceMediaMaxSpeed                              Integer32,
#    sysInterfaceMediaMaxDuplex                             INTEGER,
#    sysInterfaceMediaActiveSpeed                           Integer32,
#    sysInterfaceMediaActiveDuplex                          INTEGER,
#    sysInterfaceMacAddr                                    MacAddress,
#    sysInterfaceMtu                                        Integer32,
#    sysInterfaceEnabled                                    INTEGER,
#    sysInterfaceLearnMode                                  INTEGER,
#    sysInterfaceFlowCtrlReq                                INTEGER,
#    sysInterfaceStpLink                                    INTEGER,
#    sysInterfaceStpEdge                                    INTEGER,
#    sysInterfaceStpEdgeActive                              INTEGER,
#    sysInterfaceStpAuto                                    INTEGER,
#    sysInterfaceStpEnable                                  INTEGER,
#    sysInterfaceStpReset                                   INTEGER,
#    sysInterfaceStatus                                     INTEGER,
#    sysInterfaceComboPort                                  INTEGER,
#    sysInterfacePreferSfp                                  INTEGER,
#    sysInterfaceSfpMedia                                   INTEGER,
#    sysInterfacePhyMaster                                  INTEGER

# sysInterfaceStatEntry
#    sysInterfaceStatName                                   LongDisplayString,
#    sysInterfaceStatPktsIn                                 Counter64,
#    sysInterfaceStatBytesIn                                Counter64,
#    sysInterfaceStatPktsOut                                Counter64,
#    sysInterfaceStatBytesOut                               Counter64,
#    sysInterfaceStatMcastIn                                Counter64,
#    sysInterfaceStatMcastOut                               Counter64,
#    sysInterfaceStatErrorsIn                               Counter64,
#    sysInterfaceStatErrorsOut                              Counter64,
#    sysInterfaceStatDropsIn                                Counter64,
#    sysInterfaceStatDropsOut                               Counter64,
#    sysInterfaceStatCollisions                             Counter64,
#    sysInterfaceStatPauseActive                            INTEGER

module NewRelic
  module F5Plugin

    class Interfaces
      attr_accessor :names, :snmp_manager

      INTERFACE_ENABLED_STATES = {
        0 => 'Disabled',
        1 => 'Enabled',
      }
      INTERFACE_STATUS_STATES = {
        0 => 'Up',
        1 => 'Down',
        3 => 'Uninitialized',
        5 => 'Unpopulated',
      }
      INTERFACE_DUPLEX_STATES = {
        0 => 'None',
        1 => 'Half',
        2 => 'Full',
      }

      OID_SYS_INTERFACES                    = "1.3.6.1.4.1.3375.2.1.2.4"

      # Config
      OID_SYS_INTERFACE                     = "#{OID_SYS_INTERFACES}.1"
      OID_SYS_INTERFACE_ENTRY               = "#{OID_SYS_INTERFACE}.2.1"

      OID_SYS_INTERFACE_NAME                = "#{OID_SYS_INTERFACE_ENTRY}.1"
      OID_SYS_INTERFACE_MEDIA_MAX_SPEED     = "#{OID_SYS_INTERFACE_ENTRY}.2"
      OID_SYS_INTERFACE_MEDIA_MAX_DUPLEX    = "#{OID_SYS_INTERFACE_ENTRY}.3"
      OID_SYS_INTERFACE_MEDIA_ACTIVE_SPEED  = "#{OID_SYS_INTERFACE_ENTRY}.4"
      OID_SYS_INTERFACE_MEDIA_ACTIVE_DUPLEX = "#{OID_SYS_INTERFACE_ENTRY}.5"
      OID_SYS_INTERFACE_MAC_ADDR            = "#{OID_SYS_INTERFACE_ENTRY}.6"
      OID_SYS_INTERFACE_MTU                 = "#{OID_SYS_INTERFACE_ENTRY}.7"
      OID_SYS_INTERFACE_ENABLED             = "#{OID_SYS_INTERFACE_ENTRY}.8"
      OID_SYS_INTERFACE_STATUS              = "#{OID_SYS_INTERFACE_ENTRY}.17"

      # Stats
      OID_SYS_INTERFACE_STAT                = "#{OID_SYS_INTERFACES}.4"
      OID_SYS_INTERFACE_STAT_ENTRY          = "#{OID_SYS_INTERFACE_STAT}.3.1"

      OID_SYS_INTERFACE_STAT_NAME           = "#{OID_SYS_INTERFACE_STAT_ENTRY}.1"
      OID_SYS_INTERFACE_STAT_PKTS_IN        = "#{OID_SYS_INTERFACE_STAT_ENTRY}.2"
      OID_SYS_INTERFACE_STAT_BYTES_IN       = "#{OID_SYS_INTERFACE_STAT_ENTRY}.3"
      OID_SYS_INTERFACE_STAT_PKTS_OUT       = "#{OID_SYS_INTERFACE_STAT_ENTRY}.4"
      OID_SYS_INTERFACE_STAT_BYTES_OUT      = "#{OID_SYS_INTERFACE_STAT_ENTRY}.5"
      OID_SYS_INTERFACE_STAT_MCAST_IN       = "#{OID_SYS_INTERFACE_STAT_ENTRY}.6"
      OID_SYS_INTERFACE_STAT_MCAST_OUT      = "#{OID_SYS_INTERFACE_STAT_ENTRY}.7"
      OID_SYS_INTERFACE_STAT_ERRORS_IN      = "#{OID_SYS_INTERFACE_STAT_ENTRY}.8"
      OID_SYS_INTERFACE_STAT_ERRORS_OUT     = "#{OID_SYS_INTERFACE_STAT_ENTRY}.9"
      OID_SYS_INTERFACE_STAT_DROPS_IN       = "#{OID_SYS_INTERFACE_STAT_ENTRY}.10"
      OID_SYS_INTERFACE_STAT_DROPS_OUT      = "#{OID_SYS_INTERFACE_STAT_ENTRY}.11"
      OID_SYS_INTERFACE_STAT_COLLISIONS     = "#{OID_SYS_INTERFACE_STAT_ENTRY}.12"



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
          throughput_in = get_throughput_in
          throughput_in.each_key { |m| agent.report_counter_metric m, "bits/sec", throughput_in[m] } unless throughput_in.nil?

          throughput_out = get_throughput_out
          throughput_out.each_key { |m| agent.report_counter_metric m, "bits/sec", throughput_out[m] } unless throughput_out.nil?

          packets_in = get_packets_in
          packets_in.each_key { |m| agent.report_counter_metric m, "pkts/sec", packets_in[m] } unless packets_in.nil?

          packets_out = get_packets_out
          packets_out.each_key { |m| agent.report_counter_metric m, "pkts/sec", packets_out[m] } unless packets_out.nil?

          mcast_in = get_mcast_in
          mcast_in.each_key { |m| agent.report_counter_metric m, "pkts/sec", mcast_in[m] } unless mcast_in.nil?

          mcast_out = get_mcast_out
          mcast_out.each_key { |m| agent.report_counter_metric m, "pkts/sec", mcast_out[m] } unless mcast_out.nil?

          errors_in = get_errors_in
          errors_in.each_key { |m| agent.report_counter_metric m, "errors/sec", errors_in[m] } unless errors_in.nil?

          errors_out = get_errors_out
          errors_out.each_key { |m| agent.report_counter_metric m, "errors/sec", errors_out[m] } unless errors_out.nil?

          drops_in = get_drops_in
          drops_in.each_key { |m| agent.report_counter_metric m, "drops/sec", drops_in[m] } unless drops_in.nil?

          drops_out = get_drops_out
          drops_out.each_key { |m| agent.report_counter_metric m, "drops/sec", drops_out[m] } unless drops_out.nil?

          collisions = get_collisions
          collisions.each_key { |m| agent.report_counter_metric m, "collisions/sec", collisions[m] } unless collisions.nil?

          status = get_status
          status.each_key { |m| agent.report_metric m, status[m][:label], status[m][:count] } unless status.nil?
        end
      end



      #
      # Get the list of Interface names
      #
      def get_names(snmp = nil)
        snmp = snmp_manager unless snmp

        if snmp
          @names.clear

          begin
            snmp.walk([OID_SYS_INTERFACE_NAME]) do |row|
              row.each do |vb|
                @names.push(vb.value)
              end
            end
          rescue Exception => e
            NewRelic::PlatformLogger.error("Unable to gather Interface names with error: #{e}")
          end

          NewRelic::PlatformLogger.debug("Interfaces: Found #{@names.size} interfaces")
          return @names
        end
      end



      #
      # Gather Throughput Inbound (returns in bits)
      #
      def get_throughput_in(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Throughput/In", @names, OID_SYS_INTERFACE_STAT_BYTES_IN, snmp)
        res = res.each_key { |n| res[n] *= 8 }
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Inbound Throughput metrics")
        return res
      end



      #
      # Gather Throughput Inbound (returns in bits)
      #
      def get_throughput_out(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Throughput/Out", @names, OID_SYS_INTERFACE_STAT_BYTES_OUT, snmp)
        res = res.each_key { |n| res[n] *= 8 }
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Outbound Throughput metrics")
        return res
      end



      #
      # Gather Packets Inbound
      #
      def get_packets_in(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Packets/In", @names, OID_SYS_INTERFACE_STAT_PKTS_IN, snmp)
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Inbound packet metrics")
        return res
      end



      #
      # Gather Packets Outbound
      #
      def get_packets_out(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Packets/Out", @names, OID_SYS_INTERFACE_STAT_PKTS_OUT, snmp)
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Outbound packet metrics")
        return res
      end



      #
      # Gather Multicast Packets Inbound
      #
      def get_mcast_in(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Multicast/In", @names, OID_SYS_INTERFACE_STAT_MCAST_IN, snmp)
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Inbound multicast metrics")
        return res
      end



      #
      # Gather Multicast Packets Outbound
      #
      def get_mcast_out(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Multicast/Out", @names, OID_SYS_INTERFACE_STAT_MCAST_OUT, snmp)
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Outbound multicast metrics")
        return res
      end



      #
      # Gather Errors Inbound
      #
      def get_errors_in(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Errors/In", @names, OID_SYS_INTERFACE_STAT_ERRORS_IN, snmp)
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Inbound error metrics")
        return res
      end



      #
      # Gather Errors Outbound
      #
      def get_errors_out(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Errors/Out", @names, OID_SYS_INTERFACE_STAT_ERRORS_OUT, snmp)
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Outbound error metrics")
        return res
      end



      #
      # Gather Drops Inbound
      #
      def get_drops_in(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Drops/In", @names, OID_SYS_INTERFACE_STAT_DROPS_IN, snmp)
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Inbound drop metrics")
        return res
      end



      #
      # Gather Drops Outbound
      #
      def get_drops_out(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Drops/Out", @names, OID_SYS_INTERFACE_STAT_DROPS_OUT, snmp)
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Outbound drop metrics")
        return res
      end



      #
      # Gather Collisions
      #
      def get_collisions(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Interfaces/Collisions", @names, OID_SYS_INTERFACE_STAT_COLLISIONS, snmp)
        NewRelic::PlatformLogger.debug("Interfaces: Got #{res.size}/#{@names.size} Collision metrics")
        return res
      end



      #
      # Gather Interface Status
      #
      def get_status(snmp = nil)
        snmp = snmp_manager unless snmp
        metrics = { }
        counter = 0

        if snmp
          # Init all the states with zeros so we always get them
          base_name = "Interfaces/Status"
          INTERFACE_STATUS_STATES.each do |key,value|
            metrics["#{base_name}/#{value}"] = { :label => "interfaces", :count => 0 }
          end

          # ltmNodeAddrMonitorStatus
          begin
            snmp.walk([OID_SYS_INTERFACE_STATUS]) do |row|
              row.each do |vb|
                metric_name = "#{base_name}/#{INTERFACE_STATUS_STATES[vb.value.to_i]}"
                metrics[metric_name][:count]  += 1
                counter += 1
              end
            end
          rescue Exception => e
            NewRelic::PlatformLogger.error("Unable to gather Interface status metrics with error: #{e}")
          end
        end

        NewRelic::PlatformLogger.debug("Interfaces: Got #{counter} Status metrics")
        return metrics
      end

    end
  end
end

