#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'

module NewRelic::F5Plugin
  VERSION = '1.0.16'

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


      # Device wide metrics
      NewRelic::PlatformLogger.debug("Collecting System stats")
      @system ||= NewRelic::F5Plugin::Device.new
      @system.poll(self, snmp)

      # Device Interface metrics
      NewRelic::PlatformLogger.debug("Collecting Interface stats")
      @interfaces ||= NewRelic::F5Plugin::Interfaces.new
      @interfaces.poll(self, snmp)

      # Node stats
      NewRelic::PlatformLogger.debug("Collecting Node stats")
      @nodes ||= NewRelic::F5Plugin::Nodes.new
      @nodes.poll(self, snmp)

      # Collect virtual server statistics
      NewRelic::PlatformLogger.debug("Collecting Virtual Server stats")
      @virtuals ||= NewRelic::F5Plugin::Virtuals.new
      @virtuals.poll(self, snmp)

      # Collect pool statistics
      NewRelic::PlatformLogger.debug("Collecting Pool stats")
      @pools ||= NewRelic::F5Plugin::Pools.new
      @pools.poll(self, snmp)

      # iRule statistics
      NewRelic::PlatformLogger.debug("Collecting iRule stats")
      @rules ||= NewRelic::F5Plugin::Rules.new
      @rules.poll(self, snmp)

      # Collect snat pool statistics
      NewRelic::PlatformLogger.debug("Collecting SNAT Pool stats")
      @snatpools ||= NewRelic::F5Plugin::SnatPools.new
      @snatpools.poll(self, snmp)

      # Collect Client SSL Profile statistics
      NewRelic::PlatformLogger.debug("Collecting Client SSL Profile stats")
      @clientssl ||= NewRelic::F5Plugin::ClientSsl.new
      @clientssl.poll(self, snmp)

      # Cleanup snmp connection
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

