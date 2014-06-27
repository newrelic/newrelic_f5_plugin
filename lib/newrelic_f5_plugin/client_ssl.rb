#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'

#LtmClientSslStatEntry
#  ltmClientSslStatName                                   LongDisplayString,
#  ltmClientSslStatCurConns                               CounterBasedGauge64,
#  ltmClientSslStatMaxConns                               Counter64,
#  ltmClientSslStatCurNativeConns                         CounterBasedGauge64,
#  ltmClientSslStatMaxNativeConns                         Counter64,
#  ltmClientSslStatTotNativeConns                         Counter64,
#  ltmClientSslStatCurCompatConns                         CounterBasedGauge64,
#  ltmClientSslStatMaxCompatConns                         Counter64,
#  ltmClientSslStatTotCompatConns                         Counter64,
#  ltmClientSslStatEncryptedBytesIn                       Counter64,
#  ltmClientSslStatEncryptedBytesOut                      Counter64,
#  ltmClientSslStatDecryptedBytesIn                       Counter64,
#  ltmClientSslStatDecryptedBytesOut                      Counter64,
#  ltmClientSslStatRecordsIn                              Counter64,
#  ltmClientSslStatRecordsOut                             Counter64,
#  ltmClientSslStatFullyHwAcceleratedConns                Counter64,
#  ltmClientSslStatPartiallyHwAcceleratedConns            Counter64,
#  ltmClientSslStatNonHwAcceleratedConns                  Counter64,
#  ltmClientSslStatPrematureDisconnects                   Counter64,
#  ltmClientSslStatMidstreamRenegotiations                Counter64,
#  ltmClientSslStatSessCacheCurEntries                    CounterBasedGauge64,
#  ltmClientSslStatSessCacheHits                          Counter64,
#  ltmClientSslStatSessCacheLookups                       Counter64,
#  ltmClientSslStatSessCacheOverflows                     Counter64,
#  ltmClientSslStatSessCacheInvalidations                 Counter64,
#  ltmClientSslStatPeercertValid                          Counter64,
#  ltmClientSslStatPeercertInvalid                        Counter64,
#  ltmClientSslStatPeercertNone                           Counter64,
#  ltmClientSslStatHandshakeFailures                      Counter64,
#  ltmClientSslStatBadRecords                             Counter64,
#  ltmClientSslStatFatalAlerts                            Counter64,
#  ltmClientSslStatSslv2                                  Counter64,
#  ltmClientSslStatSslv3                                  Counter64,
#  ltmClientSslStatTlsv1                                  Counter64,
#  ltmClientSslStatAdhKeyxchg                             Counter64,
#  ltmClientSslStatDhDssKeyxchg                           Counter64,
#  ltmClientSslStatDhRsaKeyxchg                           Counter64,
#  ltmClientSslStatDssKeyxchg                             Counter64,
#  ltmClientSslStatEdhDssKeyxchg                          Counter64,
#  ltmClientSslStatRsaKeyxchg                             Counter64,
#  ltmClientSslStatNullBulk                               Counter64,
#  ltmClientSslStatAesBulk                                Counter64,
#  ltmClientSslStatDesBulk                                Counter64,
#  ltmClientSslStatIdeaBulk                               Counter64,
#  ltmClientSslStatRc2Bulk                                Counter64,
#  ltmClientSslStatRc4Bulk                                Counter64,
#  ltmClientSslStatNullDigest                             Counter64,
#  ltmClientSslStatMd5Digest                              Counter64,
#  ltmClientSslStatShaDigest                              Counter64,
#  ltmClientSslStatNotssl                                 Counter64,
#  ltmClientSslStatEdhRsaKeyxchg                          Counter64,
#  ltmClientSslStatSecureHandshakes                       Counter64,
#  ltmClientSslStatInsecureHandshakeAccepts               Counter64,
#  ltmClientSslStatInsecureHandshakeRejects               Counter64,
#  ltmClientSslStatInsecureRenegotiationRejects           Counter64,
#  ltmClientSslStatSniRejects                             Counter64,
#  ltmClientSslStatTlsv11                                 Counter64,
#  ltmClientSslStatTlsv12                                 Counter64,
#  ltmClientSslStatDtlsv1                                 Counter64

module NewRelic
  module F5Plugin

    class ClientSsl
      attr_accessor :names, :snmp_manager

      OID_LTM_CLIENT_SSL                                     = "1.3.6.1.4.1.3375.2.2.6.2"
      OID_LTM_CLIENT_SSL_PROFILE_STAT                        = "#{OID_LTM_CLIENT_SSL}.2"
      OID_LTM_CLIENT_SSL_STAT_ENTRY                          = "#{OID_LTM_CLIENT_SSL_PROFILE_STAT}.3.1"
      OID_LTM_CLIENT_SSL_STAT_NAME                           = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.1"
      OID_LTM_CLIENT_SSL_STAT_CUR_CONNS                      = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.2"
      OID_LTM_CLIENT_SSL_STAT_MAX_CONNS                      = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.3"
      OID_LTM_CLIENT_SSL_STAT_CUR_NATIVE_CONNS               = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.4"
      OID_LTM_CLIENT_SSL_STAT_MAX_NATIVE_CONNS               = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.5"

      OID_LTM_CLIENT_SSL_STAT_FULLY_HW_ACCELERATED_CONNS     = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.16"
      OID_LTM_CLIENT_SSL_STAT_PARTIALLY_HW_ACCELERATED_CONNS = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.17"
      OID_LTM_CLIENT_SSL_STAT_NON_HW_ACCELERATED_CONNS       = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.18"

      OID_LTM_CLIENT_SSL_STAT_SESS_CACHE_CUR_ENTRIES         = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.21"
      OID_LTM_CLIENT_SSL_STAT_SESS_CACHE_HITS                = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.22"
      OID_LTM_CLIENT_SSL_STAT_SESS_CACHE_LOOKUPS             = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.23"
      OID_LTM_CLIENT_SSL_STAT_SESS_CACHE_OVERFLOWS           = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.24"
      OID_LTM_CLIENT_SSL_STAT_SESS_CACHE_INVALIDATIONS       = "#{OID_LTM_CLIENT_SSL_STAT_ENTRY}.25"



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
          clientssl_conns_current = get_conns_current
          clientssl_conns_current.each_key { |m| agent.report_metric m, "conns", clientssl_conns_current[m] } unless clientssl_conns_current.nil?

          clientssl_session_cache_current = get_session_cache_current
          clientssl_session_cache_current.each_key { |m| agent.report_metric m, "entries", clientssl_session_cache_current[m] } unless clientssl_session_cache_current.nil?

          clientssl_session_cache_hits = get_session_cache_hits
          clientssl_session_cache_hits.each_key { |m| agent.report_counter_metric m, "hits/sec", clientssl_session_cache_hits[m] } unless clientssl_session_cache_hits.nil?

          clientssl_session_cache_lookups = get_session_cache_lookups
          clientssl_session_cache_lookups.each_key { |m| agent.report_counter_metric m, "lookups/sec", clientssl_session_cache_lookups[m] } unless clientssl_session_cache_lookups.nil?

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
          clientssl_hit_ratio.each_key { |m| agent.report_metric m, "%", clientssl_hit_ratio[m] } unless clientssl_hit_ratio.empty?

          clientssl_session_cache_overflows = get_session_cache_overflows
          clientssl_session_cache_overflows.each_key { |m| agent.report_counter_metric m, "overflows/sec", clientssl_session_cache_overflows[m] } unless clientssl_session_cache_overflows.nil?

          clientssl_session_cache_invalidations = get_session_cache_invalidations
          clientssl_session_cache_invalidations.each_key { |m| agent.report_counter_metric m, "invld/sec", clientssl_session_cache_invalidations[m] } unless clientssl_session_cache_invalidations.nil?
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
            snmp.walk([OID_LTM_CLIENT_SSL_STAT_NAME]) do |row|
              row.each do |vb|
                @names.push(vb.value)
              end
            end
          rescue Exception => e
            NewRelic::PlatformLogger.error("Unable to gather Client SSL Profile names with error: #{e}")
          end

          NewRelic::PlatformLogger.debug("Client SSL Profiles: Found #{@names.size}")
          return @names
        end
      end



      #
      # Gather current connection count
      #
      def get_conns_current(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Client SSL Profiles/Current Connections", @names, OID_LTM_CLIENT_SSL_STAT_CUR_CONNS, snmp)
        NewRelic::PlatformLogger.debug("Client SSL Profiles: Got #{res.size}/#{@names.size} Current Connection metrics")
        return res
      end



      #
      # Gather current cache entries
      #
      def get_session_cache_current(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Client SSL Profiles/Current Cache Entries", @names, OID_LTM_CLIENT_SSL_STAT_SESS_CACHE_CUR_ENTRIES, snmp)
        NewRelic::PlatformLogger.debug("Client SSL Profiles: Got #{res.size}/#{@names.size} Current Session Cache metrics")
        return res
      end



      #
      # Gather session cache hits
      #
      def get_session_cache_hits(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Client SSL Profiles/Session Cache Hits", @names, OID_LTM_CLIENT_SSL_STAT_SESS_CACHE_HITS, snmp)
        NewRelic::PlatformLogger.debug("Client SSL Profiles: Got #{res.size}/#{@names.size} Session Cache Hit metrics")
        return res
      end



      #
      # Gather session cache lookups
      #
      def get_session_cache_lookups(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Client SSL Profiles/Session Cache Lookups", @names, OID_LTM_CLIENT_SSL_STAT_SESS_CACHE_LOOKUPS, snmp)
        NewRelic::PlatformLogger.debug("Client SSL Profiles: Got #{res.size}/#{@names.size} Session Cache Lookup metrics")
        return res
      end



      #
      # Gather session cache overflows
      #
      def get_session_cache_overflows(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Client SSL Profiles/Session Cache Overflows", @names, OID_LTM_CLIENT_SSL_STAT_SESS_CACHE_OVERFLOWS, snmp)
        NewRelic::PlatformLogger.debug("Client SSL Profiles: Got #{res.size}/#{@names.size} Session Cache Overflow metrics")
        return res
      end



      #
      # Gather session cache invalidations
      #
      def get_session_cache_invalidations(snmp = nil)
        snmp = snmp_manager unless snmp

        get_names(snmp) if @names.empty?
        res = gather_snmp_metrics_by_name("Client SSL Profiles/Session Cache Invalidations", @names, OID_LTM_CLIENT_SSL_STAT_SESS_CACHE_INVALIDATIONS, snmp)
        NewRelic::PlatformLogger.debug("Client SSL Profiles: Got #{res.size}/#{@names.size} Session Cache Invalidation metrics")
        return res
      end
    end
  end
end

