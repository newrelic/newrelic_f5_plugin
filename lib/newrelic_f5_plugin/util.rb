#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'



#
# Walk the SNMP OIDs
#
def gather_snmp_metrics_by_name(metric_prefix, metric_names, oids, snmp = nil)
  metrics = { }
  index   = 0
  snmp    = snmp_manager unless snmp

  if metric_prefix.nil? or metric_prefix.empty?
    NewRelic::PlatformLogger.debug("Invalid metric_prefix passed to gather_snmp_metrics")
    return metrics
  end

  if metric_names.nil? or metric_names.empty? or not metric_names.kind_of?(Array)
    NewRelic::PlatformLogger.debug("Invalid metric_names passed to gather_snmp_metrics")
    return metrics
  end

  if oids.nil? or oids.empty?
    NewRelic::PlatformLogger.debug("Invalid oids passed to gather_snmp_metrics")
    return metrics
  end

  # Convert to Array if not passed as one
  oids = [oids] if not oids.kind_of?(Array)

  metric_prefix = "#{metric_prefix}/" unless metric_prefix.end_with?("/")

  if snmp
    begin
      snmp.walk(oids) do |row|
        row.each do |vb|
          metrics["#{metric_prefix}#{metric_names[index]}"] = vb.value.to_i
          index += 1
        end
      end
    rescue Exception => e
      NewRelic::PlatformLogger.error("Unable to gather SNMP metrics with error: #{e}")
    end
  end

  return metrics
end

