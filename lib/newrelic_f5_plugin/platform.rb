#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'

module NewRelic
  module F5Plugin

    class Platform
      attr_accessor :snmp_manager

      # Create the OIDs if they do not exist
      OID_SYS_GLOBAL_HOST                                    = "1.3.6.1.4.1.3375.2.1.1.2.20"
      OID_SYS_GLOBAL_HOST_CPU_COUNT                          = "#{OID_SYS_GLOBAL_HOST}.4.0"
      OID_SYS_GLOBAL_HOST_CPU_IDLE_1M                        = "#{OID_SYS_GLOBAL_HOST}.25.0"
      OID_SYS_GLOBAL_HOST_CPU_IOWAIT_1M                      = "#{OID_SYS_GLOBAL_HOST}.28.0"
      OID_SYS_GLOBAL_HOST_CPU_IRQ_1M                         = "#{OID_SYS_GLOBAL_HOST}.26.0"
      OID_SYS_GLOBAL_HOST_CPU_NICE_1M                        = "#{OID_SYS_GLOBAL_HOST}.23.0"
      OID_SYS_GLOBAL_HOST_CPU_SOFTIRQ_1M                     = "#{OID_SYS_GLOBAL_HOST}.27.0"
      OID_SYS_GLOBAL_HOST_CPU_SYSTEM_1M                      = "#{OID_SYS_GLOBAL_HOST}.24.0"
      OID_SYS_GLOBAL_HOST_CPU_USER_1M                        = "#{OID_SYS_GLOBAL_HOST}.22.0"
      OID_SYS_HOST_MEMORY_USED                               = "1.3.6.1.4.1.3375.2.1.7.1.2.0"

      OID_SYS_PLATFORM                                       = "1.3.6.1.4.1.3375.2.1.3"
      OID_SYS_PLATFORM_INFO                                  = "#{OID_SYS_PLATFORM}.5"
      OID_SYS_PLATFORM_INFO_NAME                             = "#{OID_SYS_PLATFORM_INFO}.1.0"
      OID_SYS_PLATFORM_INFO_MARKETING_NAME                   = "#{OID_SYS_PLATFORM_INFO}.2.0"

      OID_SYS_PRODUCT                                        = "1.3.6.1.4.1.3375.2.1.4"
      OID_SYS_PRODUCT_NAME                                   = "#{OID_SYS_PRODUCT}.1.0"
      OID_SYS_PRODUCT_VERSION                                = "#{OID_SYS_PRODUCT}.2.0"
      OID_SYS_PRODUCT_BUILD                                  = "#{OID_SYS_PRODUCT}.3.0"
      OID_SYS_PRODUCT_EDITION                                = "#{OID_SYS_PRODUCT}.4.0"

      #
      # Init
      #
      def initialize(snmp = nil)
        @version = 'Unknown!'

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

        system_platform = get_platform_info
        @version        = get_version
        NewRelic::PlatformLogger.debug("Found a #{system_platform} running version #{@version}")


        system_cpu = get_cpu
        system_cpu.each_key { |m| agent.report_metric m, "%", system_cpu[m] } unless system_cpu.nil?

        system_memory = get_memory
        system_memory.each_key { |m| agent.report_metric m, "bytes", system_memory[m] } unless system_memory.nil?

      end



      #
      # Gather Version information
      #
      def get_version(snmp = nil)
        version = "Unknown!"
        snmp    = snmp_manager unless snmp

        if snmp
          res = gather_snmp_metrics_array([OID_SYS_PRODUCT_VERSION, OID_SYS_PRODUCT_BUILD], snmp)

          version = "#{res[0]}.#{res[1]}" unless res.empty?
        end

        return version
      end



      def get_platform_info(snmp = nil)
        platform = "Unknown!"
        snmp     = snmp_manager unless snmp

        if snmp
          res = gather_snmp_metrics_array([OID_SYS_PLATFORM_INFO_MARKETING_NAME, OID_SYS_PLATFORM_INFO_NAME], snmp)

          platform = "#{res[0]} (#{res[1]})"
        end

        return platform
      end



      #
      # Gather CPU Related metrics and report them in %
      #
      def get_cpu(snmp = nil)
        metrics = { }
        snmp    = snmp_manager unless snmp

        if snmp
          res = gather_snmp_metrics_array([OID_SYS_GLOBAL_HOST_CPU_COUNT, OID_SYS_GLOBAL_HOST_CPU_USER_1M, OID_SYS_GLOBAL_HOST_CPU_NICE_1M,
                                           OID_SYS_GLOBAL_HOST_CPU_SYSTEM_1M, OID_SYS_GLOBAL_HOST_CPU_IRQ_1M, OID_SYS_GLOBAL_HOST_CPU_SOFTIRQ_1M,
                                           OID_SYS_GLOBAL_HOST_CPU_IOWAIT_1M],
                                           snmp)

          # Bail out if we didn't get anything
          return metrics if res.empty?

          # In order to show the CPU usage as a total percentage, we divide by the number of cpus for older versions
          case @version
          when /^11\.[0-4]\.0/
            cpu_count = res[0].to_i
          else
            # 11.4.1 HF3 reports average CPU not total, so don't divide by CPU count
            cpu_count = 1
          end

          vals = res[1..6].map { |i| i.to_f / cpu_count }

          metrics["CPU/Global/User"]     = vals[0]
          metrics["CPU/Global/Nice"]     = vals[1]
          metrics["CPU/Global/System"]   = vals[2]
          metrics["CPU/Global/IRQ"]      = vals[3]
          metrics["CPU/Global/Soft IRQ"] = vals[4]
          metrics["CPU/Global/IO Wait"]  = vals[5]

          # Add it all up, and send a summary metric
          metrics["CPU/Total/Global"] = vals.inject(0.0){ |a,b| a + b }

        end

        return metrics
      end


      #
      # Gather Memory related metrics and report them in bytes
      #
      def get_memory(snmp = nil)
        metrics = { }
        snmp    = snmp_manager unless snmp

        if snmp
          res = gather_snmp_metrics_array([OID_SYS_HOST_MEMORY_USED], snmp)

          # Bail out if we didn't get anything
          return metrics if res.empty?

          metrics["Memory/Host"] = res[0]
        end

        return metrics
      end

    end
  end
end

