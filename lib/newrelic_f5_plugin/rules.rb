#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'

#LtmRuleEventStatEntry
#  ltmRuleEventStatName                                   LongDisplayString,
#  ltmRuleEventStatEventType                              LongDisplayString,
#  ltmRuleEventStatPriority                               INTEGER,
#  ltmRuleEventStatFailures                               Integer32,
#  ltmRuleEventStatAborts                                 Integer32,
#  ltmRuleEventStatTotalExecutions                        Integer32,
#  ltmRuleEventStatAvgCycles                              Integer32,
#  ltmRuleEventStatMaxCycles                              Integer32,
#  ltmRuleEventStatMinCycles                              Integer32


module NewRelic
  module F5Plugin

    class Rules
      attr_accessor :names, :snmp_manager

      OID_LTM_RULES                 = "1.3.6.1.4.1.3375.2.2.8"
      OID_LTM_RULE_STAT             = "#{OID_LTM_RULES}.3"
      OID_LTM_RULE_ENTRY            = "#{OID_LTM_RULE_STAT}.3.1"
      OID_LTM_RULE_STAT_NAME        = "#{OID_LTM_RULE_ENTRY}.1"
      OID_LTM_RULE_STAT_TYPE        = "#{OID_LTM_RULE_ENTRY}.2"
      OID_LTM_RULE_STAT_FAILURES    = "#{OID_LTM_RULE_ENTRY}.4"
      OID_LTM_RULE_STAT_ABORTS      = "#{OID_LTM_RULE_ENTRY}.5"
      OID_LTM_RULE_STAT_TOT_EXEC    = "#{OID_LTM_RULE_ENTRY}.6"
      OID_LTM_RULE_STAT_AVG_CYCLES  = "#{OID_LTM_RULE_ENTRY}.7"



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
          rule_execs = get_executions
          rule_execs.each_key { |m| agent.report_counter_metric m, "execs/sec", rule_execs[m] } unless rule_execs.nil?

          rule_failures = get_failures
          rule_failures.each_key { |m| agent.report_counter_metric m, "failures/sec", rule_failures[m] } unless rule_failures.nil?

          rule_aborts = get_aborts
          rule_aborts.each_key { |m| agent.report_counter_metric m, "aborts/sec", rule_aborts[m] } unless rule_aborts.nil?

          rule_cycles = get_average_cycles
          rule_cycles.each_key { |m| agent.report_metric m, "cycles", rule_cycles[m] } unless rule_cycles.nil?
        end
      end


      #
      # Get the list of iRule names
      #
      def get_names(snmp = nil)
        snmp = snmp_manager unless snmp

        if snmp
          @names.clear

          begin
            snmp.walk([OID_LTM_RULE_STAT_NAME, OID_LTM_RULE_STAT_TYPE]) do |rule, func|
              @names.push("#{rule.value}/#{func.value}")
            end
          rescue Exception => e
            NewRelic::PlatformLogger.error("Unable to gather iRule names with error: #{e}")
          end

          NewRelic::PlatformLogger.debug("Rules: Found #{@names.size} iRules")
          return @names
        end
      end



      #
      # Gather Total iRule Executions
      #
      def get_executions(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Rules/Executions", @names, OID_LTM_RULE_STAT_TOT_EXEC, snmp)
        NewRelic::PlatformLogger.debug("Rules: Got #{res.size}/#{@names.size} Execution metrics")
        return res
      end



      #
      # Gather Total iRule Failures
      #
      def get_failures(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Rules/Failures", @names, OID_LTM_RULE_STAT_FAILURES, snmp)
        NewRelic::PlatformLogger.debug("Rules: Got #{res.size}/#{@names.size} Failure metrics")
        return res
      end



      #
      # Gather Total iRule Aborts
      #
      def get_aborts(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Rules/Aborts", @names, OID_LTM_RULE_STAT_ABORTS, snmp)
        NewRelic::PlatformLogger.debug("Rules: Got #{res.size}/#{@names.size} Abort metrics")
        return res
      end



      #
      # Gather Average iRule execution time (in cycles)
      #
      def get_average_cycles(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Rules/Time", @names, OID_LTM_RULE_STAT_AVG_CYCLES, snmp)
        NewRelic::PlatformLogger.debug("Rules: Got #{res.size}/#{@names.size} Average Cycle metrics")
        return res
      end



    end
  end
end

