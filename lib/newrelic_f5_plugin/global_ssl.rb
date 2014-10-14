#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'

module NewRelic
  module F5Plugin

    class GlobalSsl
      attr_accessor :snmp_manager

      # Create the OIDs if they do not exist
      OID_SYS_GLOBAL_STATS                     = "1.3.6.1.4.1.3375.2.1.1.2"
      OID_SYS_GLOBAL_CLIENT_SSL_STAT           = "#{OID_SYS_GLOBAL_STATS}.9"
      OID_SYS_GLOBAL_SERVER_SSL_STAT           = "#{OID_SYS_GLOBAL_STATS}.10"

      # Client-side Connections
      OID_SYS_CLIENTSSL_STAT_CUR_CONNS         = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.2.0"
      OID_SYS_CLIENTSSL_STAT_TOT_COMPAT_CONNS  = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.9.0"
      OID_SYS_CLIENTSSL_STAT_TOT_NATIVE_CONNS  = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.6.0"
      # Server-side Connections
      OID_SYS_SERVERSSL_STAT_CUR_CONNS         = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.2.0"
      OID_SYS_SERVERSSL_STAT_TOT_COMPAT_CONNS  = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.9.0"
      OID_SYS_SERVERSSL_STAT_TOT_NATIVE_CONNS  = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.6.0"

      # Client-side Protocols
      OID_SYS_CLIENTSSL_STAT_SSLV2             = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.32.0"
      OID_SYS_CLIENTSSL_STAT_SSLV3             = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.33.0"
      OID_SYS_CLIENTSSL_STAT_TLSV1             = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.34.0"
      # Server-side Protocols
      OID_SYS_SERVERSSL_STAT_SSLV2             = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.32.0"
      OID_SYS_SERVERSSL_STAT_SSLV3             = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.33.0"
      OID_SYS_SERVERSSL_STAT_TLSV1             = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.34.0"

      # Client-side Key Exchanges
      OID_SYS_CLIENTSSL_STAT_ADH_KEYXCHG       = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.35.0"
      OID_SYS_CLIENTSSL_STAT_DHRSA_KEYXCHG     = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.37.0"
      OID_SYS_CLIENTSSL_STAT_RSA_KEYXCHG       = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.40.0"
      OID_SYS_CLIENTSSL_STAT_EDHRSA_KEYXCHG    = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.51.0"
      # Server-side Key Exchanges
      OID_SYS_SERVERSSL_STAT_ADH_KEYXCHG       = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.35.0"
      OID_SYS_SERVERSSL_STAT_DHRSA_KEYXCHG     = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.37.0"
      OID_SYS_SERVERSSL_STAT_RSA_KEYXCHG       = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.40.0"
      OID_SYS_SERVERSSL_STAT_EDHRSA_KEYXCHG    = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.51.0"

      # Client-side Bulk
      OID_SYS_CLIENTSSL_STAT_NULL_BULK         = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.41.0"
      OID_SYS_CLIENTSSL_STAT_AES_BULK          = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.42.0"
      OID_SYS_CLIENTSSL_STAT_DES_BULK          = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.43.0"
      OID_SYS_CLIENTSSL_STAT_IDEA_BULK         = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.44.0"
      OID_SYS_CLIENTSSL_STAT_RC2_BULK          = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.45.0"
      OID_SYS_CLIENTSSL_STAT_RC4_BULK          = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.46.0"
      # Server-side Bulk
      OID_SYS_SERVERSSL_STAT_NULL_BULK         = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.41.0"
      OID_SYS_SERVERSSL_STAT_AES_BULK          = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.42.0"
      OID_SYS_SERVERSSL_STAT_DES_BULK          = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.43.0"
      OID_SYS_SERVERSSL_STAT_IDEA_BULK         = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.44.0"
      OID_SYS_SERVERSSL_STAT_RC2_BULK          = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.45.0"
      OID_SYS_SERVERSSL_STAT_RC4_BULK          = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.46.0"

      # Client-side Digests
      OID_SYS_CLIENTSSL_STAT_NULL_DIGEST       = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.47.0"
      OID_SYS_CLIENTSSL_STAT_MD5_DIGEST        = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.48.0"
      OID_SYS_CLIENTSSL_STAT_SHA_DIGEST        = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.49.0"
      OID_SYS_CLIENTSSL_STAT_NOTSSL            = "#{OID_SYS_GLOBAL_CLIENT_SSL_STAT}.50.0"
      # Server-side Digests
      OID_SYS_SERVERSSL_STAT_NULL_DIGEST       = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.47.0"
      OID_SYS_SERVERSSL_STAT_MD5_DIGEST        = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.48.0"
      OID_SYS_SERVERSSL_STAT_SHA_DIGEST        = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.49.0"
      OID_SYS_SERVERSSL_STAT_NOTSSL            = "#{OID_SYS_GLOBAL_SERVER_SSL_STAT}.50.0"



      #
      # Init
      #
      def initialize(snmp = nil)
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

        ssl_total_connections = get_connections
        ssl_total_connections.each_key { |m| agent.report_metric m, "conn", ssl_total_connections[m] } unless ssl_total_connections.nil?

        ssl_conns = get_ssl_conns
        ssl_conns.each_key { |m| agent.report_counter_metric m, "trans/sec", ssl_conns[m] } unless ssl_conns.nil?

        ssl_conns = get_ssl_conns
        ssl_conns.each_key { |m| agent.report_counter_metric m, "trans/sec", ssl_conns[m] } unless ssl_conns.nil?

        ssl_protocols = get_ssl_protocols
        ssl_protocols.each_key { |m| agent.report_counter_metric m, "trans/sec", ssl_protocols[m] } unless ssl_protocols.nil?

        ssl_key_exchanges = get_ssl_key_exchanges
        ssl_key_exchanges.each_key { |m| agent.report_counter_metric m, "trans/sec", ssl_key_exchanges[m] } unless ssl_key_exchanges.nil?

        ssl_bulk = get_ssl_bulk
        ssl_bulk.each_key { |m| agent.report_counter_metric m, "trans/sec", ssl_bulk[m] } unless ssl_bulk.nil?

        ssl_digests = get_ssl_digests
        ssl_digests.each_key { |m| agent.report_counter_metric m, "trans/sec", ssl_digests[m] } unless ssl_digests.nil?
      end



      #
      # Gather Global connection related metrics and report them in conn
      #
      def get_connections(snmp = nil)
        metrics = { }
        snmp    = snmp_manager unless snmp

        if snmp
          res = gather_snmp_metrics_array([ OID_SYS_CLIENTSSL_STAT_CUR_CONNS, OID_SYS_SERVERSSL_STAT_CUR_CONNS], snmp)

          # Bail out if we didn't get anything
          return metrics if res.empty?

          metrics["Connections/Current/Client SSL"] = res[0]
          metrics["Connections/Current/Server SSL"] = res[1]
        end

        return metrics
      end



      #
      # Global SSL Connection Stats in trans/sec
      #
      def get_ssl_conns(snmp = nil)
        metrics = { }
        snmp    = snmp_manager unless snmp

        if snmp
          res = gather_snmp_metrics_array([OID_SYS_CLIENTSSL_STAT_TOT_NATIVE_CONNS, OID_SYS_CLIENTSSL_STAT_TOT_COMPAT_CONNS,
                                           OID_SYS_SERVERSSL_STAT_TOT_NATIVE_CONNS, OID_SYS_SERVERSSL_STAT_TOT_COMPAT_CONNS],
                                           snmp)

          # Bail out if we didn't get anything
          return metrics if res.empty?

          vals = res.map { |i| i.to_i }

          metrics["SSL/Global/Client/Native"] = vals[0]
          metrics["SSL/Global/Client/Compat"] = vals[1]
          metrics["SSL/Global/Server/Native"] = vals[2]
          metrics["SSL/Global/Server/Compat"] = vals[3]
          metrics["SSL/Global/Total/Client"]  = (vals[0] + vals[1])
          metrics["SSL/Global/Total/Server"]  = (vals[2] + vals[3])
          metrics["SSL/Global/Total/All"]     = vals.inject(0) { |t,i| t + i }
        end

        return metrics
      end



      #
      # Global SSL Protocol Stats in trans/sec
      #
      def get_ssl_protocols(snmp = nil)
        metrics = { }
        snmp    = snmp_manager unless snmp

        if snmp

          res = gather_snmp_metrics_array([OID_SYS_CLIENTSSL_STAT_SSLV2, OID_SYS_CLIENTSSL_STAT_SSLV3, OID_SYS_CLIENTSSL_STAT_TLSV1,
                                           OID_SYS_SERVERSSL_STAT_SSLV2, OID_SYS_SERVERSSL_STAT_SSLV3, OID_SYS_SERVERSSL_STAT_TLSV1],
                                           snmp)

          # Bail out if we didn't get anything
          return metrics if res.empty?

          vals = res.map { |i| i.to_i }

          metrics["SSL/Global/Protocol/Client/SSLv2"] = vals[0]
          metrics["SSL/Global/Protocol/Client/SSLv3"] = vals[1]
          metrics["SSL/Global/Protocol/Client/TLSv1"] = vals[2]
          metrics["SSL/Global/Protocol/Server/SSLv2"] = vals[3]
          metrics["SSL/Global/Protocol/Server/SSLv3"] = vals[4]
          metrics["SSL/Global/Protocol/Server/TLSv1"] = vals[5]
        end

        return metrics
      end



      #
      # Global SSL Key Exchanges Stats in trans/sec
      #
      def get_ssl_key_exchanges(snmp = nil)
        metrics = { }
        snmp    = snmp_manager unless snmp

        if snmp

          res = gather_snmp_metrics_array([OID_SYS_CLIENTSSL_STAT_ADH_KEYXCHG, OID_SYS_CLIENTSSL_STAT_DHRSA_KEYXCHG, OID_SYS_CLIENTSSL_STAT_RSA_KEYXCHG, OID_SYS_CLIENTSSL_STAT_EDHRSA_KEYXCHG,
                                           OID_SYS_SERVERSSL_STAT_ADH_KEYXCHG, OID_SYS_SERVERSSL_STAT_DHRSA_KEYXCHG, OID_SYS_SERVERSSL_STAT_RSA_KEYXCHG, OID_SYS_SERVERSSL_STAT_EDHRSA_KEYXCHG],
                                           snmp)

          # Bail out if we didn't get anything
          return metrics if res.empty?

          vals = res.map { |i| i.to_i }

          metrics["SSL/Global/KeyExchange/Client/Adh"]    = vals[0]
          metrics["SSL/Global/KeyExchange/Client/DhRSA"]  = vals[1]
          metrics["SSL/Global/KeyExchange/Client/RSA"]    = vals[2]
          metrics["SSL/Global/KeyExchange/Client/EdhRsa"] = vals[3]
          metrics["SSL/Global/KeyExchange/Server/Adh"]    = vals[4]
          metrics["SSL/Global/KeyExchange/Server/DhRSA"]  = vals[5]
          metrics["SSL/Global/KeyExchange/Server/RSA"]    = vals[6]
          metrics["SSL/Global/KeyExchange/Server/EdhRsa"] = vals[7]
        end

        return metrics
      end



      #
      # Global SSL Bulk Stats in trans/sec
      #
      def get_ssl_bulk(snmp = nil)
        metrics = { }
        snmp    = snmp_manager unless snmp

        if snmp

          res = gather_snmp_metrics_array([OID_SYS_CLIENTSSL_STAT_NULL_BULK, OID_SYS_CLIENTSSL_STAT_AES_BULK, OID_SYS_CLIENTSSL_STAT_DES_BULK, OID_SYS_CLIENTSSL_STAT_IDEA_BULK,
                                           OID_SYS_CLIENTSSL_STAT_RC2_BULK, OID_SYS_CLIENTSSL_STAT_RC4_BULK, OID_SYS_SERVERSSL_STAT_NULL_BULK, OID_SYS_SERVERSSL_STAT_AES_BULK,
                                           OID_SYS_SERVERSSL_STAT_DES_BULK, OID_SYS_SERVERSSL_STAT_IDEA_BULK, OID_SYS_SERVERSSL_STAT_RC2_BULK, OID_SYS_SERVERSSL_STAT_RC4_BULK],
                                           snmp)

          # Bail out if we didn't get anything
          return metrics if res.empty?

          vals = res.map { |i| i.to_i }

          metrics["SSL/Global/Bulk/Client/Null"] = vals[0]
          metrics["SSL/Global/Bulk/Client/AES"]  = vals[1]
          metrics["SSL/Global/Bulk/Client/DES"]  = vals[2]
          metrics["SSL/Global/Bulk/Client/IDEA"] = vals[3]
          metrics["SSL/Global/Bulk/Client/RC2"]  = vals[4]
          metrics["SSL/Global/Bulk/Client/RC4"]  = vals[5]

          metrics["SSL/Global/Bulk/Server/Null"] = vals[6]
          metrics["SSL/Global/Bulk/Server/AES"]  = vals[7]
          metrics["SSL/Global/Bulk/Server/DES"]  = vals[8]
          metrics["SSL/Global/Bulk/Server/IDEA"] = vals[9]
          metrics["SSL/Global/Bulk/Server/RC2"]  = vals[10]
          metrics["SSL/Global/Bulk/Server/RC4"]  = vals[11]
        end

        return metrics
      end



      #
      # Global SSL Digest Stats in trans/sec
      #
      def get_ssl_digests(snmp = nil)
        metrics = { }
        snmp    = snmp_manager unless snmp

        if snmp

          res = gather_snmp_metrics_array([OID_SYS_CLIENTSSL_STAT_NULL_DIGEST, OID_SYS_CLIENTSSL_STAT_MD5_DIGEST, OID_SYS_CLIENTSSL_STAT_SHA_DIGEST, OID_SYS_CLIENTSSL_STAT_NOTSSL,
                                           OID_SYS_SERVERSSL_STAT_NULL_DIGEST, OID_SYS_SERVERSSL_STAT_MD5_DIGEST, OID_SYS_SERVERSSL_STAT_SHA_DIGEST, OID_SYS_SERVERSSL_STAT_NOTSSL],
                                           snmp)

          # Bail out if we didn't get anything
          return metrics if res.empty?

          vals = res.map { |i| i.to_i }

          metrics["SSL/Global/Digest/Client/Null"]   = vals[0]
          metrics["SSL/Global/Digest/Client/MD5"]    = vals[1]
          metrics["SSL/Global/Digest/Client/SHA"]    = vals[2]
          metrics["SSL/Global/Digest/Client/NotSSL"] = vals[3]
          metrics["SSL/Global/Digest/Server/Null"]   = vals[4]
          metrics["SSL/Global/Digest/Server/MD5"]    = vals[5]
          metrics["SSL/Global/Digest/Server/SHA"]    = vals[6]
          metrics["SSL/Global/Digest/Server/NotSSL"] = vals[7]
        end

        return metrics
      end


    end
  end
end

