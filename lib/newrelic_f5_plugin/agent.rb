#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'newrelic_plugin'
require 'snmp'


module NewRelic::F5Plugin

  # Register and run the agent
  def self.run
    # Register this agent.
    NewRelic::Plugin::Setup.install_agent :f5, self

    # Launch the agent; this never returns.
    NewRelic::Plugin::Run.setup_and_run
  end



  class Agent < NewRelic::Plugin::Agent::Base
    agent_guid    '3e768a422cae01fe59cc15d255933ec896b32792'
    agent_version '0.0.1'
    agent_config_options :hostname, :port, :snmp_community
    agent_human_labels('F5 LTM') { "#{hostname}" }

    def setup_metrics
      # We have to define our custom OIDs of SNMP complains
      @oid_sysStatMemoryUsed        = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.45.0")
      @oid_sysHostMemoryUsed        = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.7.1.2.0")
      @oid_sysStatClientCurConns    = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.8.0")
      @oid_sysStatServerCurConns    = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.15.0")
      #@oid_sysStatPvaClientCurConns = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.22.0")
      #@oid_sysStatPvaServerCurConns = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.29.0")
      @oid_sysClientsslStatCurConns = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.9.2.0")
      @oid_sysServersslStatCurConns = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.10.2.0")

      # These OIDs need rates applied to them
      #@oid_sysTcpStatAccepts     = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.6.0")
      @oid_sysStatClientTotConns = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.7.0")
      @oid_sysStatServerTotConns = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.14.0")
      @sysStatClientTotConns     = NewRelic::Processor::EpochCounter.new
      @sysStatServerTotConns     = NewRelic::Processor::EpochCounter.new

      # Throughput
      @oid_sysStatClientBytesIn  = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.3.0")
      @oid_sysStatClientBytesOut = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.5.0")
      @oid_sysStatServerBytesIn  = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.10.0")
      @oid_sysStatServerBytesOut = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.12.0")
      @sysStatClientBytesIn      = NewRelic::Processor::EpochCounter.new
      @sysStatClientBytesOut     = NewRelic::Processor::EpochCounter.new
      @sysStatServerBytesIn      = NewRelic::Processor::EpochCounter.new
      @sysStatServerBytesOut     = NewRelic::Processor::EpochCounter.new


      # HTTP Requests
      @oid_sysStatHttpRequests = SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.56.0")
      @sysStatHttpRequests     = NewRelic::Processor::EpochCounter.new
    end

    def poll_cycle
      # SNMP Stuff here
      SNMP::Manager.open(:host => hostname, :port => port, :community => snmp_community) do |snmp|
        res = snmp.get_value([@oid_sysStatMemoryUsed,
                              @oid_sysHostMemoryUsed,
                              @oid_sysStatClientCurConns,
                              @oid_sysStatServerCurConns,
                              @oid_sysStatClientTotConns,
                              @oid_sysStatServerTotConns,
                              @oid_sysClientsslStatCurConns,
                              @oid_sysServersslStatCurConns,
                              @oid_sysStatClientBytesIn,
                              @oid_sysStatClientBytesOut,
                              @oid_sysStatServerBytesIn,
                              @oid_sysStatServerBytesOut,
                              @oid_sysStatHttpRequests,
                             ])

        # This is ugly, but the SNMP module isn't very friendly (or at least the docs aren't)
        report_metric "Memory/TMM",                 "bytes",    res[0]
        report_metric "Memory/Host",                "bytes",    res[1]
        report_metric "Connections/Current/Client", "conn",     res[2]
        report_metric "Connections/Current/Server", "conn",     res[3]
        report_metric "Connections/Current/Client SSL",     "conn",     res[6]
        report_metric "Connections/CurrentServer SSL",     "conn",     res[7]
        report_metric "Connections/Rate/Client",    "conn/sec", @sysStatClientTotConns.process(res[4])
        report_metric "Connections/Rate/Server",    "conn/sec", @sysStatServerTotConns.process(res[5])

        # These need to be multiplied by 8 to get Bits (They are in Bytes)
        report_metric "Throughput/Client/In",  "bytes/sec", @sysStatClientBytesIn.process(res[8])
        report_metric "Throughput/Client/Out", "bytes/sec", @sysStatClientBytesOut.process(res[9])
        report_metric "Throughput/Server/In",  "bytes/sec", @sysStatServerBytesIn.process(res[10])
        report_metric "Throughput/Server/Out", "bytes/sec", @sysStatServerBytesOut.process(res[11])

        report_metric "HTTP/Global/Requests", "req/sec", @sysStatHttpRequests.process(res[12])
      end
    rescue => e
      $stderr.puts "#{e}: #{e.backtrace.join("\n  ")}"
    end
  end

end

