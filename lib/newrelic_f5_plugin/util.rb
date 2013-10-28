#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'



#
# Walk the SNMP OIDs
#
def gather_snmp_metrics_by_name(metric_prefix, metric_names, oids, snmp)
  metrics = { }
  index   = 0

  if metric_prefix.nil? or metric_prefix.empty?
    NewRelic::PlatformLogger.debug("Invalid metric_prefix passed to gather_snmp_metrics_by_name")
    return metrics
  end

  if metric_names.nil? or metric_names.empty? or not metric_names.kind_of?(Array)
    NewRelic::PlatformLogger.debug("Invalid metric_names passed to gather_snmp_metrics_by_name")
    return metrics
  end

  if oids.nil? or oids.empty?
    NewRelic::PlatformLogger.debug("Invalid oids passed to gather_snmp_metrics_by_name")
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


#
# Return all of the OID values in an array
#
def gather_snmp_metrics_array(oids, snmp)
  metrics = [ ]

  if oids.nil? or oids.empty?
    NewRelic::PlatformLogger.debug("Invalid oids passed to gather_snmp_metrics_array")
    return metrics
  end

  # Convert to Array if not passed as one
  oids = [oids] if not oids.kind_of?(Array)

  if snmp
    begin
      metrics = snmp.get_value(oids).map do |val|
        # If an OID is missing, just return zero for that metric
        if val.to_s == 'noSuchObject'
          0
        else
          val
        end
      end
    rescue Exception => e
      NewRelic::PlatformLogger.error("Unable to gather SNMP metrics with error: #{e}")
    end
  end

  return metrics
end


#
# Convert bytes to bits
#
def bytes_to_bits(vals)
  ret = nil

  if vals.class == Array
    ret = vals.map { |i| i.to_f * 8 }
  elsif vals.class == Hash
    ret = { }
    vals.keys.each do |k,v|
      if v.nil?
        ret[k] = v
      else
        ret[k] = v.to_f * 8
      end
    end
  end

  return ret
end


