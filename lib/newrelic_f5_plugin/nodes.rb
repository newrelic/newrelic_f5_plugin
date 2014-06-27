#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'


module NewRelic
  module F5Plugin

    class Nodes
      attr_accessor :snmp_manager

      NODE_MONITOR_STATES = {
        0  => 'unchecked',
        1  => 'checking',
        2  => 'inband',
        3  => 'forced-up',
        4  => 'up',
        19 => 'down',
        20 => 'forced-down',
        21 => 'maint',
        22 => 'irule-down',
        23 => 'inband-down',
        24 => 'down-manual-resume',
        25 => 'disabled',
      }

      OID_LTM_NODE_ADDR_MONITOR_STATUS = "1.3.6.1.4.1.3375.2.2.4.1.2.1.7"


      #
      # Init
      #
      def initialize(snmp = nil)
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

        node_status = get_status
        node_status.each_key { |m| agent.report_metric m, node_status[m][:label], node_status[m][:count] } unless node_status.nil?
      end



      #
      # Node Naming in SNMP
      #
      # vb.name = SNMPv2-SMI::enterprises.3375.2.2.4.1.2.1.7.{name length}.{name in dot seperated ASCII code} (because why not...)
      #tmp_name = vb.name.to_s.gsub(/SNMPv2-SMI::enterprises\.3375\.2\.2\.4\.1\.2\.1\.7\.\d+\./, '').split('.').collect! { |c| c.to_i.chr }  # Create an array of the ASCII chars of the node name
      #name = tmp_name.join

      #
      # Gather Node Status and report
      #
      def get_status(snmp = nil)
        snmp = snmp_manager unless snmp
        metrics = { }
        counter = 0

        if snmp
          # Init all the states with zeros so we always get them
          base_name = "Nodes/Monitor Status"
          NODE_MONITOR_STATES.each do |key,value|
            metrics["#{base_name}/#{value}"] = { :label => "nodes", :count => 0 }
          end

          # ltmNodeAddrMonitorStatus
          begin
            snmp.walk([OID_LTM_NODE_ADDR_MONITOR_STATUS]) do |row|
              row.each do |vb|
                metric_name = "#{base_name}/#{NODE_MONITOR_STATES[vb.value.to_i]}"
                metrics[metric_name][:count]  += 1
                counter += 1
              end
            end
          rescue Exception => e
            NewRelic::PlatformLogger.error("Unable to gather Node Status metrics with error: #{e}")
          end
        end

        NewRelic::PlatformLogger.debug("Nodes: Got #{counter} Status metrics")
        return metrics
      end

    end
  end
end

