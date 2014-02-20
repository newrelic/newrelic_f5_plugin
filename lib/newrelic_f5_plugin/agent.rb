#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'

module NewRelic::F5Plugin
  VERSION = '1.0.13'

  # Register and run the agent
  def self.run
    # Register this agent.
    NewRelic::Plugin::Setup.install_agent :f5, self

    # Launch the agent; this never returns.
    NewRelic::Plugin::Run.setup_and_run
  end


  # Part of me wants to split this out into different devices using this OID:
  #   1.3.6.1.4.1.3375.2.1.3.5.2.0 = STRING: "BIG-IP 3900" or
  #   1.3.6.1.4.1.3375.2.1.3.5.1.0 = STRING: "C106"
  # Especially since a 3900, 6900, Viprion won't respond exactly the same.
  # To make it worse, versions of BIG-IP older than 11.2 might not implent all
  # all of these OIDs.
  #   Version: 1.3.6.1.4.1.3375.2.1.4.2.0
  #     Build: 1.3.6.1.4.1.3375.2.1.4.3.0
  class Agent < NewRelic::Plugin::Agent::Base
    agent_guid    'com.newrelic.f5'
    agent_version VERSION
    agent_config_options :hostname, :port, :snmp_community, :agent_name
    agent_human_labels('F5') { "#{agent_label}" }

    #
    #
    #
    def agent_label
      return agent_name unless agent_name.nil?
      return hostname
    end


    #
    # Required, but not used
    #
    def setup_metrics
    end


    #
    # This is called on every polling cycle
    #
    def poll_cycle
      NewRelic::PlatformLogger.debug("Starting poll cycle for '#{hostname}'")

      # SNMP Stuff here
      snmp = SNMP::Manager.new(:host => hostname, :port => port, :community => snmp_community)

      #
      # Test our SNMP connection, return if we fail to connect so the entire agent doesn't quit
      #
      begin
        product_name = snmp.get_value(["1.3.6.1.4.1.3375.2.1.4.1.0"]).first
        NewRelic::PlatformLogger.debug("Found F5 device of type: '#{product_name}'")
      rescue SNMP::RequestTimeout
        NewRelic::PlatformLogger.error("Unable to connect to device: '#{hostname}', skipping...")
        snmp.close
        return
      rescue => e
        NewRelic::PlatformLogger.error(e)
        snmp.close
        return
      end


      #
      # Device wide metrics
      #
      system = NewRelic::F5Plugin::Device.new snmp

      system_version = system.get_version
      NewRelic::PlatformLogger.debug("Found F5 device with version: #{system_version}")
      NewRelic::PlatformLogger.debug("Collecting System stats")

      system_cpu = system.get_cpu
      system_cpu.each_key { |m| report_metric m, "%", system_cpu[m] } unless system_cpu.nil?

      system_memory = system.get_memory
      system_memory.each_key { |m| report_metric m, "bytes", system_memory[m] } unless system_memory.nil?

      system_connections = system.get_connections
      system_connections.each_key { |m| report_metric m, "conn", system_connections[m] } unless system_connections.nil?

      system_connection_rates = system.get_connection_rates
      system_connection_rates.each_key { |m| report_counter_metric m, "conn/sec", system_connection_rates[m] } unless system_connection_rates.nil?

      system_throughput = system.get_throughput
      system_throughput.each_key { |m| report_counter_metric m, "bits/sec", system_throughput[m] } unless system_throughput.nil?

      system_http_reqs = system.get_http_requests
      system_http_reqs.each_key { |m| report_counter_metric m, "req/sec", system_http_reqs[m] } unless system_http_reqs.nil?

      system_http_resp = system.get_http_responses
      system_http_resp.each_key { |m| report_counter_metric m, "resp/sec", system_http_resp[m] } unless system_http_resp.nil?

      system_http_compression = system.get_http_compression
      system_http_compression.each_key { |m| report_counter_metric m, "bits/sec", system_http_compression[m] } unless system_http_compression.nil?

      system_ssl = system.get_ssl
      system_ssl.each_key { |m| report_counter_metric m, "trans/sec", system_ssl[m] } unless system_ssl.nil?

      system_tcp_conns = system.get_tcp_connections
      system_tcp_conns.each_key { |m| report_metric m, "conn", system_tcp_conns[m] } unless system_tcp_conns.nil?

      system_tcp_conn_rates = system.get_tcp_connection_rates
      system_tcp_conn_rates.each_key { |m| report_counter_metric m, "conn/sec", system_tcp_conn_rates[m] } unless system_tcp_conn_rates.nil?

      system_tcp_syn_rates = system.get_tcp_syn_rates
      system_tcp_syn_rates.each_key { |m| report_counter_metric m, "SYN/sec", system_tcp_syn_rates[m] } unless system_tcp_syn_rates.nil?

      system_tcp_segment_rates = system.get_tcp_segment_rates
      system_tcp_segment_rates.each_key { |m| report_counter_metric m, "segments/sec", system_tcp_segment_rates[m] } unless system_tcp_segment_rates.nil?

      system_tcp_error_rates = system.get_tcp_error_rates
      system_tcp_error_rates.each_key { |m| report_counter_metric m, "errs/sec", system_tcp_error_rates[m] } unless system_tcp_error_rates.nil?


      #
      # Node stats
      #
      NewRelic::PlatformLogger.debug("Collecting Node stats")
      nodes = NewRelic::F5Plugin::Nodes.new snmp
      node_status = nodes.get_status
      node_status.each_key { |m| report_metric m, node_status[m][:label], node_status[m][:count] } unless node_status.nil?

      #
      # Collect virtual server statistics
      #
      NewRelic::PlatformLogger.debug("Collecting Virtual Server stats")
      vs = NewRelic::F5Plugin::Virtuals.new snmp

      unless vs.get_names.empty?
        virtual_requests = vs.get_requests
        virtual_requests.each_key { |m| report_counter_metric m, "req/sec", virtual_requests[m] } unless virtual_requests.nil?

        virtual_conns_current = vs.get_conns_current
        virtual_conns_current.each_key { |m| report_metric m, "conns", virtual_conns_current[m] } unless virtual_conns_current.nil?

        virtual_conns_total = vs.get_conns_total
        virtual_conns_total.each_key { |m| report_counter_metric m, "conn/sec", virtual_conns_total[m] } unless virtual_conns_total.nil?

        virtual_packets_in = vs.get_packets_in
        virtual_packets_in.each_key { |m| report_counter_metric m, "packets/sec", virtual_packets_in[m] } unless virtual_packets_in.nil?

        virtual_packets_out = vs.get_packets_out
        virtual_packets_out.each_key { |m| report_counter_metric m, "packets/sec", virtual_packets_out[m] } unless virtual_packets_out.nil?

        virtual_throughput_in = vs.get_throughput_in
        virtual_throughput_in.each_key { |m| report_counter_metric m, "bits/sec", virtual_throughput_in[m] } unless virtual_throughput_in.nil?

        virtual_throughput_out = vs.get_throughput_out
        virtual_throughput_out.each_key { |m| report_counter_metric m, "bits/sec", virtual_throughput_out[m] } unless virtual_throughput_out.nil?

        virtual_cpu_usage_1m = vs.get_cpu_usage_1m
        virtual_cpu_usage_1m.each_key { |m| report_metric m, "%", virtual_cpu_usage_1m[m] } unless virtual_cpu_usage_1m.nil?
      end

      #
      # Collect pool statistics
      #
      NewRelic::PlatformLogger.debug("Collecting Pool stats")
      pool = NewRelic::F5Plugin::Pools.new snmp

      unless pool.get_names.empty?
        pool_requests = pool.get_requests
        pool_requests.each_key { |m| report_counter_metric m, "req/sec", pool_requests[m] } unless pool_requests.nil?

        pool_conns_current = pool.get_conns_current
        pool_conns_current.each_key { |m| report_metric m, "conns", pool_conns_current[m] } unless pool_conns_current.nil?

        pool_conns_total = pool.get_conns_total
        pool_conns_total.each_key { |m| report_counter_metric m, "conn/sec", pool_conns_total[m] } unless pool_conns_total.nil?

        pool_packets_in = pool.get_packets_in
        pool_packets_in.each_key { |m| report_counter_metric m, "packets/sec", pool_packets_in[m] } unless pool_packets_in.nil?

        pool_packets_out = pool.get_packets_out
        pool_packets_out.each_key { |m| report_counter_metric m, "packets/sec", pool_packets_out[m] } unless pool_packets_out.nil?

        pool_throughput_in = pool.get_throughput_in
        pool_throughput_in.each_key { |m| report_counter_metric m, "bits/sec", pool_throughput_in[m] } unless pool_throughput_in.nil?

        pool_throughput_out = pool.get_throughput_out
        pool_throughput_out.each_key { |m| report_counter_metric m, "bits/sec", pool_throughput_out[m] } unless pool_throughput_out.nil?
      end


      #
      # iRule statistics
      #
      NewRelic::PlatformLogger.debug("Collecting iRule stats")
      rule = NewRelic::F5Plugin::Rules.new snmp

      unless rule.get_names.empty?
        rule_execs = rule.get_executions
        rule_execs.each_key { |m| report_counter_metric m, "execs/sec", rule_execs[m] } unless rule_execs.nil?

        rule_failures = rule.get_failures
        rule_failures.each_key { |m| report_counter_metric m, "failures/sec", rule_failures[m] } unless rule_failures.nil?

        rule_aborts = rule.get_aborts
        rule_aborts.each_key { |m| report_counter_metric m, "aborts/sec", rule_aborts[m] } unless rule_aborts.nil?

        rule_cycles = rule.get_average_cycles
        rule_cycles.each_key { |m| report_metric m, "cycles", rule_cycles[m] } unless rule_cycles.nil?
      end


      #
      # Collect snat pool statistics
      #
      NewRelic::PlatformLogger.debug("Collecting SNAT Pool stats")
      snatpool = NewRelic::F5Plugin::SnatPools.new snmp

      unless snatpool.get_names.empty?
        snatpool_conns_max = snatpool.get_conns_max
        snatpool_conns_max.each_key { |m| report_metric m, "conns", snatpool_conns_max[m] } unless snatpool_conns_max.nil?

        snatpool_conns_current = snatpool.get_conns_current
        snatpool_conns_current.each_key { |m| report_metric m, "conns", snatpool_conns_current[m] } unless snatpool_conns_current.nil?

        snatpool_conns_total = snatpool.get_conns_total
        snatpool_conns_total.each_key { |m| report_counter_metric m, "conn/sec", snatpool_conns_total[m] } unless snatpool_conns_total.nil?

        snatpool_throughput_in = snatpool.get_throughput_in
        snatpool_throughput_in.each_key { |m| report_counter_metric m, "bits/sec", snatpool_throughput_in[m] } unless snatpool_throughput_in.nil?

        snatpool_throughput_out = snatpool.get_throughput_out
        snatpool_throughput_out.each_key { |m| report_counter_metric m, "bits/sec", snatpool_throughput_out[m] } unless snatpool_throughput_out.nil?

        snatpool_packets_in = snatpool.get_packets_in
        snatpool_packets_in.each_key { |m| report_counter_metric m, "pkts/sec", snatpool_packets_in[m] } unless snatpool_packets_in.nil?

        snatpool_packets_out = snatpool.get_packets_out
        snatpool_packets_out.each_key { |m| report_counter_metric m, "pkts/sec", snatpool_packets_out[m] } unless snatpool_packets_out.nil?
      end


      #
      # Collect Client SSL Profile statistics
      #
      NewRelic::PlatformLogger.debug("Collecting Client SSL Profile stats")
      clientssl = NewRelic::F5Plugin::ClientSsl.new snmp

      unless clientssl.get_names.empty?
        clientssl_conns_current = clientssl.get_conns_current
        clientssl_conns_current.each_key { |m| report_metric m, "conns", clientssl_conns_current[m] } unless clientssl_conns_current.nil?

        clientssl_session_cache_current = clientssl.get_session_cache_current
        clientssl_session_cache_current.each_key { |m| report_metric m, "entries", clientssl_session_cache_current[m] } unless clientssl_session_cache_current.nil?

        clientssl_session_cache_hits = clientssl.get_session_cache_hits
        clientssl_session_cache_hits.each_key { |m| report_counter_metric m, "hits/sec", clientssl_session_cache_hits[m] } unless clientssl_session_cache_hits.nil?

        clientssl_session_cache_lookups = clientssl.get_session_cache_lookups
        clientssl_session_cache_lookups.each_key { |m| report_counter_metric m, "lookups/sec", clientssl_session_cache_lookups[m] } unless clientssl_session_cache_lookups.nil?

        NewRelic::PlatformLogger.debug("Calculating Client SSL Profile hit ratios")
        clientssl_hit_ratio = { }
        clientssl_session_cache_hits.each_key do |h|
          key = h.gsub(/^Client SSL Profiles\/Session Cache Hits\//, '')
          l = "Client SSL Profiles/Session Cache Lookups/#{key}"
          p = "Client SSL Profiles/Session Cache Hit Ratio/#{key}"
          unless clientssl_session_cache_lookups[l].nil?
            if clientssl_session_cache_lookups[l].to_f > 0
              clientssl_hit_ratio[p] = (clientssl_session_cache_hits[h].to_f / clientssl_session_cache_lookups[l].to_f) * 100
            else
              clientssl_hit_ratio[p] = 0.0
            end
          end
        end
        clientssl_hit_ratio.each_key { |m| report_metric m, "%", clientssl_hit_ratio[m] } unless clientssl_hit_ratio.empty?

        clientssl_session_cache_overflows = clientssl.get_session_cache_overflows
        clientssl_session_cache_overflows.each_key { |m| report_counter_metric m, "overflows/sec", clientssl_session_cache_overflows[m] } unless clientssl_session_cache_overflows.nil?

        clientssl_session_cache_invalidations = clientssl.get_session_cache_invalidations
        clientssl_session_cache_invalidations.each_key { |m| report_counter_metric m, "invld/sec", clientssl_session_cache_invalidations[m] } unless clientssl_session_cache_invalidations.nil?
      end


      #
      # Cleanup snmp connection
      #
      snmp.close
    end


    #
    # You do not have to specify the SNMP port in the yaml if you don't want to.
    #
    def port
      @port || 161
    end


    #
    # Helper function to create and keep track of all the counters
    #
    def report_counter_metric(metric, type, value)
      @processors ||= {}

      if @processors[metric].nil?
        @processors[metric] = NewRelic::Processor::EpochCounter.new
      end

      report_metric metric, type, @processors[metric].process(value)
    end

  end
end

