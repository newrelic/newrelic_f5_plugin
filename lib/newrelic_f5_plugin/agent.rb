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
    agent_guid    '9edfe90795d241fa8c118f761b9789c05aa1295b'
    agent_version '0.0.2'
    agent_config_options :hostname, :port, :snmp_community
    agent_human_labels('F5') { "#{hostname}" }


    #
    # Required, but not used
    #
    def setup_metrics
    end


    #
    # This is called on every polling cycle
    #
    def poll_cycle
      # SNMP Stuff here
      snmp = SNMP::Manager.open(:host => hostname, :port => port, :community => snmp_community)

      report_cpu_metics(snmp)
      report_memory_metrics(snmp)
      report_global_connection_metrics(snmp)
      report_global_throughput_metrics(snmp)
      report_global_http_metrics(snmp)
      report_global_tcp_metrics(snmp)

      snmp.close
    rescue => e
      $stderr.puts "#{e}: #{e.backtrace.join("\n  ")}"
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


    #
    # Gather CPU Related metrics and report them
    #
    def report_cpu_metrics(snmp)
      # Create the OIDs if they do not exist
      @oid_sysGlobalHostCpuUser1m    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.22.0")
      @oid_sysGlobalHostCpuNice1m    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.23.0")
      @oid_sysGlobalHostCpuSystem1m  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.24.0")
      @oid_sysGlobalHostCpuIdle1m    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.25.0")
      @oid_sysGlobalHostCpuIrq1m     ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.26.0")
      @oid_sysGlobalHostCpuSoftirq1m ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.27.0")
      @oid_sysGlobalHostCpuIowait1m  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.28.0")

      if snmp
        res = snmp.get_value([@oid_sysGlobalHostCpuUser1m, @oid_sysGlobalHostCpuNice1m, @oid_sysGlobalHostCpuSystem1m,
                              @oid_sysGlobalHostCpuIdle1m, @oid_sysGlobalHostCpuIrq1m, @oid_sysGlobalHostCpuSoftirq1m,
                              @oid_sysGlobalHostCpuIowait1m])
        report_metric "CPU/Global/User",     "%", res[0]
        report_metric "CPU/Global/Nice",     "%", res[1]
        report_metric "CPU/Global/System",   "%", res[2]
        report_metric "CPU/Global/Idle",     "%", res[3]
        report_metric "CPU/Global/IRQ",      "%", res[4]
        report_metric "CPU/Global/Soft IRQ", "%", res[5]
        report_metric "CPU/Global/IO Wait",  "%", res[6]
      end
    end


    #
    # Gather Memory related metrics and report them
    #
    def report_memory_metrics(snmp)
      # Create the OIDs if they don't exist
      @oid_sysStatMemoryUsed ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.45.0")
      @oid_sysHostMemoryUsed ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.7.1.2.0")

      if snmp
        res = snmp.get_value([@oid_sysStatMemoryUsed, @oid_sysHostMemoryUsed])
        report_metric "Memory/TMM",  "bytes", res[0]
        report_metric "Memory/Host", "bytes", res[1]
      end
    end


    #
    # Gather Global connection related metrics and report them
    #
    def report_global_connection_metrics(snmp)
      # Create the OIDs if they don't exist
      @oid_sysStatClientCurConns    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.8.0")
      @oid_sysStatServerCurConns    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.15.0")
      @oid_sysStatClientTotConns    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.7.0")
      @oid_sysStatServerTotConns    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.14.0")
      #@oid_sysStatPvaClientCurConns ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.22.0")
      #@oid_sysStatPvaServerCurConns ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.29.0")
      # These should be moved to an SSL metric...
      @oid_sysClientsslStatCurConns ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.9.2.0")
      @oid_sysServersslStatCurConns ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.10.2.0")

      if snmp
        res = snmp.get_value([@oid_sysStatClientCurConns, @oid_sysStatServerCurConns, @oid_sysStatClientTotConns,
                              @oid_sysStatServerTotConns, @oid_sysClientsslStatCurConns, @oid_sysServersslStatCurConns])
        report_metric         "Connections/Current/Client",     "conn",     res[0]
        report_metric         "Connections/Current/Server",     "conn",     res[1]
        report_counter_metric "Connections/Rate/Client",        "conn/sec", res[2]
        report_counter_metric "Connections/Rate/Server",        "conn/sec", res[3]
        report_metric         "Connections/Current/Client SSL", "conn",     res[4]
        report_metric         "Connections/Current/Server SSL", "conn",     res[5]
      end
    end


    #
    # Gather Global throughput related metrics and report them
    #
    def report_global_throughput_metrics(snmp)
      # Create the OIDs if they don't exist
      @oid_sysStatClientBytesIn  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.3.0")
      @oid_sysStatClientBytesOut ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.5.0")
      @oid_sysStatServerBytesIn  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.10.0")
      @oid_sysStatServerBytesOut ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.1.12.0")

      if snmp
        res = snmp.get_value([@oid_sysStatClientBytesIn, @oid_sysStatClientBytesOut, @oid_sysStatServerBytesIn,
                              @oid_sysStatServerBytesOut])

        report_counter_metric "Throughput/Client/In",  "bytes/sec", res[0]
        report_counter_metric "Throughput/Client/Out", "bytes/sec", res[1]
        report_counter_metric "Throughput/Server/In",  "bytes/sec", res[2]
        report_counter_metric "Throughput/Server/Out", "bytes/sec", res[3]
      end
    end


    #
    # Gather Global HTTP related metrics and report them
    #
    def report_global_http_metrics(snmp)
      # Create the OIDs if they don't exist
      @oid_sysHttpStatResp2xxCnt    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.3.0")
      @oid_sysHttpStatResp3xxCnt    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.4.0")
      @oid_sysHttpStatResp4xxCnt    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.5.0")
      @oid_sysHttpStatResp5xxCnt    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.6.0")
      @oid_sysHttpStatNumberReqs    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.7.0")
      @oid_sysHttpStatGetReqs       ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.8.0")
      @oid_sysHttpStatPostReqs      ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.9.0")
      @oid_sysHttpStatV9Reqs        ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.10.0")
      @oid_sysHttpStatV10Reqs       ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.11.0")
      @oid_sysHttpStatV11Reqs       ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.12.0")
      @oid_sysHttpStatV9Resp        ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.13.0")
      @oid_sysHttpStatV10Resp       ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.14.0")
      @oid_sysHttpStatV11Resp       ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.15.0")
      @oid_sysHttpStatRespBucket1k  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.17.0")
      @oid_sysHttpStatRespBucket4k  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.18.0")
      @oid_sysHttpStatRespBucket16k ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.19.0")
      @oid_sysHttpStatRespBucket32k ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.4.20.0")

      if snmp
        res = snmp.get_value([@oid_sysHttpStatResp2xxCnt,    @oid_sysHttpStatResp3xxCnt,    @oid_sysHttpStatResp4xxCnt,
                              @oid_sysHttpStatResp5xxCnt,    @oid_sysHttpStatNumberReqs,    @oid_sysHttpStatGetReqs,
                              @oid_sysHttpStatPostReqs,      @oid_sysHttpStatV9Reqs,        @oid_sysHttpStatV10Reqs,
                              @oid_sysHttpStatV11Reqs,       @oid_sysHttpStatV9Resp,        @oid_sysHttpStatV10Resp,
                              @oid_sysHttpStatV11Resp,       @oid_sysHttpStatRespBucket1k,  @oid_sysHttpStatRespBucket4k,
                              @oid_sysHttpStatRespBucket16k, @oid_sysHttpStatRespBucket32k, ])

        report_counter_metric "HTTP/Response Code/2xx", "resp/sec", res[0]
        report_counter_metric "HTTP/Response Code/3xx", "resp/sec", res[1]
        report_counter_metric "HTTP/Response Code/4xx", "resp/sec", res[2]
        report_counter_metric "HTTP/Response Code/5xx", "resp/sec", res[3]

        report_counter_metric "HTTP/Method/All",            "req/sec",  res[4]
        report_counter_metric "HTTP/Method/Get",            "req/sec",  res[5]
        report_counter_metric "HTTP/Method/Post",           "req/sec",  res[6]
        report_counter_metric "HTTP/Version/v0.9/Request",  "req/sec",  res[7]
        report_counter_metric "HTTP/Version/v1.0/Request",  "req/sec",  res[8]
        report_counter_metric "HTTP/Version/v1.1/Request",  "req/sec",  res[9]
        report_counter_metric "HTTP/Version/v0.9/Response", "resp/sec", res[10]
        report_counter_metric "HTTP/Version/v1.0/Response", "resp/sec", res[11]
        report_counter_metric "HTTP/Version/v1.1/Response", "resp/sec", res[12]

        report_counter_metric "HTTP/Response Size/1k Bucket",  "resp/sec", res[13]
        report_counter_metric "HTTP/Response Size/4k Bucket",  "resp/sec", res[14]
        report_counter_metric "HTTP/Response Size/16k Bucket", "resp/sec", res[15]
        report_counter_metric "HTTP/Response Size/32k Bucket", "resp/sec", res[16]
      end
    end


    #
    # Gather TCP Statistics and report them
    #
    def report_global_tcp_metrics(snmp)
      # Create the OIDs if they don't exist
      @oid_sysTcpStatOpen      ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.2.0")  # "The number of current open connections."
      @oid_sysTcpStatCloseWait ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.3.0")  # "The number of current connections in CLOSE-WAIT/LAST-ACK."
      @oid_sysTcpStatFinWait   ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.4.0")  # "The number of current connections in FIN-WAIT/CLOSING."
      @oid_sysTcpStatTimeWait  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.5.0")  # "The number of current connections in TIME-WAIT."
      @oid_sysTcpStatAccepts   ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.6.0")  # "The number of connections accepted."
      # sysTcpStatAcceptfails  1.3.6.1.4.1.3375.2.1.1.2.12.7.0   "The number of connections not accepted."
      # sysTcpStatConnects     1.3.6.1.4.1.3375.2.1.1.2.12.8.0   "The number of connections established."
      # sysTcpStatConnfails    1.3.6.1.4.1.3375.2.1.1.2.12.9.0   "The number of connection failures."
      # sysTcpStatExpires      1.3.6.1.4.1.3375.2.1.1.2.12.10.0  "The number of connections expired due to idle timeout."
      # sysTcpStatAbandons     1.3.6.1.4.1.3375.2.1.1.2.12.11.0  "The number of connections abandoned connections due to retries/keep-alives."
      # sysTcpStatRxrst        1.3.6.1.4.1.3375.2.1.1.2.12.12.0  "The number of received RST."
      # sysTcpStatRxbadsum     1.3.6.1.4.1.3375.2.1.1.2.12.13.0  "The number of bad checksum."
      # sysTcpStatRxbadseg     1.3.6.1.4.1.3375.2.1.1.2.12.14.0  "The number of malformed segments."
      # sysTcpStatRxooseg      1.3.6.1.4.1.3375.2.1.1.2.12.15.0  "The number of out of order segments."
      # sysTcpStatRxcookie     1.3.6.1.4.1.3375.2.1.1.2.12.16.0  "The number of received SYN-cookies."
      # sysTcpStatRxbadcookie  1.3.6.1.4.1.3375.2.1.1.2.12.17.0  "The number of bad SYN-cookies."
      # sysTcpStatSyncacheover 1.3.6.1.4.1.3375.2.1.1.2.12.18.0  "The number of SYN-cache overflow."
      # sysTcpStatTxrexmits    1.3.6.1.4.1.3375.2.1.1.2.12.19.0  "The number of retransmitted segments."
      if snmp
        res = snmp.get_value([@oid_sysTcpStatOpen, @oid_sysTcpStatCloseWait, @oid_sysTcpStatFinWait,
                              @oid_sysTcpStatTimeWait, @oid_sysTcpStatAccepts, ])

        report_metric         "TCP/Connection State/Open",       "conn",     res[0]
        report_metric         "TCP/Connection State/Wait/Close", "conn",     res[1]
        report_metric         "TCP/Connection State/Wait/FIN",   "conn",     res[2]
        report_metric         "TCP/Connection State/Wait/TIME",  "conn",     res[3]
        report_counter_metric "TCP/Accepts",                     "conn/sec", res[4]
      end
    end

  end
end

