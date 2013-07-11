#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'newrelic_plugin'
require 'snmp'

module NewRelic::F5Plugin
  VERSION = '1.0.1'

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
      snmp = SNMP::Manager.new(:host => hostname, :port => port, :community => snmp_community)

      report_global_cpu_metrics(snmp)
      report_global_memory_metrics(snmp)
      report_global_connection_metrics(snmp)
      report_global_throughput_metrics(snmp)
      report_global_http_metrics(snmp)
      report_global_http_compression_metrics(snmp)
      report_global_ssl_metrics(snmp)
      report_global_tcp_metrics(snmp)

      node_status = NewRelic::F5Plugin::Nodes.get_status(snmp)
      node_status.each_key { |m|
        report_metric m, node_status[m][:label], node_status[m][:count]
      }

      #
      # Collect virtual server statistics
      #
      vs = NewRelic::F5Plugin::Virtuals.new snmp
      virtual_requests = vs.get_requests
      virtual_requests.each_key { |m|
        report_counter_metric m, "req/sec", virtual_requests[m]
      }

      virtual_conns_current = vs.get_conns_current
      virtual_conns_current.each_key { |m|
        report_metric m, "conns", virtual_conns_current[m]
      }

      virtual_conns_total = vs.get_conns_total
      virtual_conns_total.each_key { |m|
        report_counter_metric m, "conn/sec", virtual_conns_total[m]
      }

      virtual_throughput_in = vs.get_throughput_in
      virtual_throughput_in.each_key { |m|
        report_counter_metric m, "bits/sec", virtual_throughput_in[m]
      }

      virtual_throughput_out = vs.get_throughput_out
      virtual_throughput_out.each_key { |m|
        report_counter_metric m, "bits/sec", virtual_throughput_out[m]
      }



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
    def report_global_cpu_metrics(snmp)
      # Create the OIDs if they do not exist
      @oid_sysGlobalHostCpuUser1m    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.22.0")
      @oid_sysGlobalHostCpuNice1m    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.23.0")
      @oid_sysGlobalHostCpuSystem1m  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.24.0")
      #@oid_sysGlobalHostCpuIdle1m    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.25.0") # Ignoring the idle time
      @oid_sysGlobalHostCpuIrq1m     ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.26.0")
      @oid_sysGlobalHostCpuSoftirq1m ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.27.0")
      @oid_sysGlobalHostCpuIowait1m  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.28.0")
      @oid_sysGlobalHostCpuCount     ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.20.4.0")

      if snmp
        res = snmp.get_value([@oid_sysGlobalHostCpuCount, @oid_sysGlobalHostCpuUser1m, @oid_sysGlobalHostCpuNice1m,
                              @oid_sysGlobalHostCpuSystem1m, @oid_sysGlobalHostCpuIrq1m, @oid_sysGlobalHostCpuSoftirq1m,
                              @oid_sysGlobalHostCpuIowait1m, ])

        # In order to show the CPU usage as a total percentage, we divide by the number of cpus
        cpu_count = res[0].to_i
        vals = res[1..6].map { |i| i.to_f / cpu_count }
        report_metric "CPU/Global/User",     "%", vals[0]
        report_metric "CPU/Global/Nice",     "%", vals[1]
        report_metric "CPU/Global/System",   "%", vals[2]
        report_metric "CPU/Global/IRQ",      "%", vals[3]
        report_metric "CPU/Global/Soft IRQ", "%", vals[4]
        report_metric "CPU/Global/IO Wait",  "%", vals[5]

        # Add it all up, and send a summary metric
        report_metric "CPU/Total/Global", "%", vals.inject(0.0){ |a,b| a + b }
      end
    end


    #
    # Gather Memory related metrics and report them
    #
    def report_global_memory_metrics(snmp)
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

        report_counter_metric "Throughput/Client/In",  "bits/sec", (res[0].to_f * 8)
        report_counter_metric "Throughput/Client/Out", "bits/sec", (res[1].to_f * 8)
        report_counter_metric "Throughput/Server/In",  "bits/sec", (res[2].to_f * 8)
        report_counter_metric "Throughput/Server/Out", "bits/sec", (res[3].to_f * 8)
        tot = 0
        res.each { |x| tot += x.to_f }
        report_counter_metric "Throughput/Total",      "bits/sec", (tot * 8)
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
    # HTTP Compression Stats
    #
    def report_global_http_compression_metrics(snmp)
      @oid_sysHttpCompressionStatPrecompressBytes       ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.2.0")
      @oid_sysHttpCompressionStatPostcompressBytes      ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.3.0")
      @oid_sysHttpCompressionStatHtmlPrecompressBytes   ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.5.0")
      @oid_sysHttpCompressionStatHtmlPostcompressBytes  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.6.0")
      @oid_sysHttpCompressionStatCssPrecompressBytes    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.7.0")
      @oid_sysHttpCompressionStatCssPostcompressBytes   ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.8.0")
      @oid_sysHttpCompressionStatJsPrecompressBytes     ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.9.0")
      @oid_sysHttpCompressionStatJsPostcompressBytes    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.10.0")
      @oid_sysHttpCompressionStatXmlPrecompressBytes    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.11.0")
      @oid_sysHttpCompressionStatXmlPostcompressBytes   ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.12.0")
      @oid_sysHttpCompressionStatSgmlPrecompressBytes   ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.13.0")
      @oid_sysHttpCompressionStatSgmlPostcompressBytes  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.14.0")
      @oid_sysHttpCompressionStatPlainPrecompressBytes  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.15.0")
      @oid_sysHttpCompressionStatPlainPostcompressBytes ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.16.0")
      @oid_sysHttpCompressionStatOctetPrecompressBytes  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.17.0")
      @oid_sysHttpCompressionStatOctetPostcompressBytes ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.18.0")
      @oid_sysHttpCompressionStatImagePrecompressBytes  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.19.0")
      @oid_sysHttpCompressionStatImagePostcompressBytes ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.20.0")
      @oid_sysHttpCompressionStatVideoPrecompressBytes  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.21.0")
      @oid_sysHttpCompressionStatVideoPostcompressBytes ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.22.0")
      @oid_sysHttpCompressionStatAudioPrecompressBytes  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.23.0")
      @oid_sysHttpCompressionStatAudioPostcompressBytes ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.24.0")
      @oid_sysHttpCompressionStatOtherPrecompressBytes  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.25.0")
      @oid_sysHttpCompressionStatOtherPostcompressBytes ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.22.26.0")

      if snmp
        res = snmp.get_value([@oid_sysHttpCompressionStatPrecompressBytes, @oid_sysHttpCompressionStatPostcompressBytes,
                              @oid_sysHttpCompressionStatHtmlPrecompressBytes, @oid_sysHttpCompressionStatHtmlPostcompressBytes,
                              @oid_sysHttpCompressionStatCssPrecompressBytes, @oid_sysHttpCompressionStatCssPostcompressBytes,
                              @oid_sysHttpCompressionStatJsPrecompressBytes, @oid_sysHttpCompressionStatJsPostcompressBytes,
                              @oid_sysHttpCompressionStatXmlPrecompressBytes, @oid_sysHttpCompressionStatXmlPostcompressBytes,
                              @oid_sysHttpCompressionStatSgmlPrecompressBytes, @oid_sysHttpCompressionStatSgmlPostcompressBytes,
                              @oid_sysHttpCompressionStatPlainPrecompressBytes, @oid_sysHttpCompressionStatPlainPostcompressBytes,
                              @oid_sysHttpCompressionStatOctetPrecompressBytes, @oid_sysHttpCompressionStatOctetPostcompressBytes,
                              @oid_sysHttpCompressionStatImagePrecompressBytes, @oid_sysHttpCompressionStatImagePostcompressBytes,
                              @oid_sysHttpCompressionStatVideoPrecompressBytes, @oid_sysHttpCompressionStatVideoPostcompressBytes,
                              @oid_sysHttpCompressionStatAudioPrecompressBytes, @oid_sysHttpCompressionStatAudioPostcompressBytes,
                              @oid_sysHttpCompressionStatOtherPrecompressBytes, @oid_sysHttpCompressionStatOtherPostcompressBytes, ])

        vals = res.map { |i| i.to_f * 8 } # Convert to bits
        report_counter_metric "HTTP/Compression/Total/Pre",       "bits/sec",  vals[0]
        report_counter_metric "HTTP/Compression/Total/Post",      "bits/sec",  vals[1]
        report_counter_metric "HTTP/Compression/HTML/Pre",        "bits/sec",  vals[2]
        report_counter_metric "HTTP/Compression/HTML/Post",       "bits/sec",  vals[3]
        report_counter_metric "HTTP/Compression/CSS/Pre",         "bits/sec",  vals[4]
        report_counter_metric "HTTP/Compression/CSS/Post",        "bits/sec",  vals[5]
        report_counter_metric "HTTP/Compression/Javascript/Pre",  "bits/sec",  vals[6]
        report_counter_metric "HTTP/Compression/Javascript/Post", "bits/sec",  vals[7]
        report_counter_metric "HTTP/Compression/XML/Pre",         "bits/sec",  vals[8]
        report_counter_metric "HTTP/Compression/XML/Post",        "bits/sec",  vals[9]
        report_counter_metric "HTTP/Compression/SGML/Pre",        "bits/sec",  vals[10]
        report_counter_metric "HTTP/Compression/SGML/Post",       "bits/sec",  vals[11]
        report_counter_metric "HTTP/Compression/Plain/Pre",       "bits/sec",  vals[12]
        report_counter_metric "HTTP/Compression/Plain/Post",      "bits/sec",  vals[13]
        report_counter_metric "HTTP/Compression/Octet/Pre",       "bits/sec",  vals[14]
        report_counter_metric "HTTP/Compression/Octet/Post",      "bits/sec",  vals[15]
        report_counter_metric "HTTP/Compression/Image/Pre",       "bits/sec",  vals[16]
        report_counter_metric "HTTP/Compression/Image/Post",      "bits/sec",  vals[17]
        report_counter_metric "HTTP/Compression/Video/Pre",       "bits/sec",  vals[18]
        report_counter_metric "HTTP/Compression/Video/Post",      "bits/sec",  vals[19]
        report_counter_metric "HTTP/Compression/Audio/Pre",       "bits/sec",  vals[20]
        report_counter_metric "HTTP/Compression/Audio/Post",      "bits/sec",  vals[21]
        report_counter_metric "HTTP/Compression/Other/Pre",       "bits/sec",  vals[22]
        report_counter_metric "HTTP/Compression/Other/Post",      "bits/sec",  vals[23]
      end
    end

    #
    # SSL Stats
    #
    def report_global_ssl_metrics(snmp)
      @oid_sysClientsslStatTotNativeConns ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.9.6.0")
      @oid_sysClientsslStatTotCompatConns ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.9.9.0")
      @oid_sysServersslStatTotNativeConns ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.10.6.0")
      @oid_sysServersslStatTotCompatConns ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.10.9.0")

      if snmp
        res = snmp.get_value([@oid_sysClientsslStatTotNativeConns, @oid_sysClientsslStatTotCompatConns, @oid_sysServersslStatTotNativeConns,
                              @oid_sysServersslStatTotCompatConns])
        vals = res.map { |i| i.to_i }
        report_counter_metric "SSL/Global/Client/Native", "trans/sec", vals[0]
        report_counter_metric "SSL/Global/Client/Compat", "trans/sec", vals[1]
        report_counter_metric "SSL/Global/Server/Native", "trans/sec", vals[2]
        report_counter_metric "SSL/Global/Server/Compat", "trans/sec", vals[3]
        report_counter_metric "SSL/Global/Total/Client",  "trans/sec", (vals[0] + vals[1])
        report_counter_metric "SSL/Global/Total/Server",  "trans/sec", (vals[2] + vals[3])
        report_counter_metric "SSL/Global/Total/All",     "trans/sec", vals.inject(0) { |t,i| t + i }
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
      # @oid_sysTcpStatAcceptfails  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.7.0")   # "The number of connections not accepted."
      # @oid_sysTcpStatConnects     ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.8.0")   # "The number of connections established."
      # @oid_sysTcpStatConnfails    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.9.0")   # "The number of connection failures."
      # @oid_sysTcpStatExpires      ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.10.0")  # "The number of connections expired due to idle timeout."
      # @oid_sysTcpStatAbandons     ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.11.0")  # "The number of connections abandoned connections due to retries/keep-alives."
      # @oid_sysTcpStatRxrst        ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.12.0")  # "The number of received RST."
      # @oid_sysTcpStatRxbadsum     ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.13.0")  # "The number of bad checksum."
      # @oid_sysTcpStatRxbadseg     ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.14.0")  # "The number of malformed segments."
      # @oid_sysTcpStatRxooseg      ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.15.0")  # "The number of out of order segments."
      # @oid_sysTcpStatRxcookie     ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.16.0")  # "The number of received SYN-cookies."
      # @oid_sysTcpStatRxbadcookie  ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.17.0")  # "The number of bad SYN-cookies."
      # @oid_sysTcpStatSyncacheover ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.18.0")  # "The number of SYN-cache overflow."
      # @oid_sysTcpStatTxrexmits    ||= SNMP::ObjectId.new("1.3.6.1.4.1.3375.2.1.1.2.12.19.0")  # "The number of retransmitted segments."
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

