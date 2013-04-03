#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'newrelic_plugin'
require 'snmp'


module NewRelic
  module F5Plugin

    module Nodes
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

      #
      # Node Naming in SNMP
      #
      # vb.name = SNMPv2-SMI::enterprises.3375.2.2.4.1.2.1.7.{name length}.{name in dot seperated ASCII code} (because why not...)
      #tmp_name = vb.name.to_s.gsub(/SNMPv2-SMI::enterprises\.3375\.2\.2\.4\.1\.2\.1\.7\.\d+\./, '').split('.').collect! { |c| c.to_i.chr }  # Create an array of the ASCII chars of the node name
      #name = tmp_name.join

      #
      # Gather Node Status and report
      #
      def self.get_status(snmp)
        if snmp
          # Init all the states with zeros so we always get them
          base_name = "Nodes/Monitor Status"
          metrics = { }
          NODE_MONITOR_STATES.each do |key,value|
            metrics["#{base_name}/#{value}"] = { :label => "nodes", :count => 0 }
          end

          # ltmNodeAddrMonitorStatus
          snmp.walk(["1.3.6.1.4.1.3375.2.2.4.1.2.1.7"]) do |row|
            row.each do |vb|
              metric_name = "#{base_name}/#{NODE_MONITOR_STATES[vb.value.to_i]}"
              metrics[metric_name][:count]  += 1
            end
          end

          return metrics
        end
      end
    end
  end
end

