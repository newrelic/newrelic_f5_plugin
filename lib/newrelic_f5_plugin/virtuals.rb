#!/usr/bin/env ruby

require 'newrelic_plugin'
require 'snmp'


module NewRelic
  module F5Plugin

    class Virtuals
      attr_accessor :vs_names, :snmp_manager

      OID_LTM_VIRTUAL_SERVERS     = "1.3.6.1.4.1.3375.2.2.10"

      OID_LTM_VIRTUAL_SERV_STAT                  = "#{OID_LTM_VIRTUAL_SERVERS}.2"
      OID_LTM_VIRTUAL_SERV_ENTRY                 = "#{OID_LTM_VIRTUAL_SERV_STAT}.3.1"
      OID_LTM_VIRTUAL_SERV_STAT_NAME             = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.1"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_IN  = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.7"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_OUT = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.9"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_TOT_CONNS = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.11"
      OID_LTM_VIRTUAL_SERV_STAT_CLIENT_CUR_CONNS = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.12"
      OID_LTM_VIRTUAL_SERV_STAT_TOT_REQUESTS     = "#{OID_LTM_VIRTUAL_SERV_ENTRY}.27"



      #
      # Init
      #
      def initialize(snmp = nil)
        @vs_names = [ ]

        if snmp
          @snmp_manager = snmp
        else
          @snmp_manager = nil
        end
      end



      #
      # Get the list of Virtual Server names
      #
      def get_names(snmp = nil)
        snmp = snmp_manager unless snmp

        if snmp
          @vs_names.clear

          snmp.walk([OID_LTM_VIRTUAL_SERV_STAT_NAME]) do |row|
            row.each do |vb|
              @vs_names.push(vb.value)
            end
          end

          return @vs_names
        end
      end



      #
      # Gather VS Total Requests
      #
      def get_requests(snmp = nil)
        metrics = { }
        index   = 0
        snmp    = snmp_manager unless snmp

        if snmp
          get_names(snmp) if @vs_names.empty?

          snmp.walk([OID_LTM_VIRTUAL_SERV_STAT_TOT_REQUESTS]) do |row|
            row.each do |vb|
              metrics["Virtual Servers/Requests/#{@vs_names[index]}"] = vb.value.to_i
              index += 1
            end
          end

          return metrics
        end
      end



      #
      # Gather VS Connection count
      #
      def get_conns_current(snmp = nil)
        metrics = { }
        index   = 0
        snmp    = snmp_manager unless snmp

        if snmp
          get_names(snmp) if @vs_names.empty?

          snmp.walk([OID_LTM_VIRTUAL_SERV_STAT_CLIENT_CUR_CONNS]) do |row|
            row.each do |vb|
              metrics["Virtual Servers/Current Connections/#{@vs_names[index]}"] = vb.value.to_i
              index += 1
            end
          end

          return metrics
        end
      end



      #
      # Gather VS Connection rate
      #
      def get_conns_total(snmp = nil)
        metrics = { }
        index   = 0
        snmp    = snmp_manager unless snmp

        if snmp
          get_names(snmp) if @vs_names.empty?

          snmp.walk([OID_LTM_VIRTUAL_SERV_STAT_CLIENT_TOT_CONNS]) do |row|
            row.each do |vb|
              metrics["Virtual Servers/Connection Rate/#{@vs_names[index]}"] = vb.value.to_i
              index += 1
            end
          end

          return metrics
        end
      end



      #
      # Gather VS Throughput Inbound (returns in bits)
      #
      def get_throughput_in(snmp = nil)
        metrics = { }
        index   = 0
        snmp    = snmp_manager unless snmp

        if snmp
          get_names(snmp) if @vs_names.empty?

          snmp.walk([OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_IN]) do |row|
            row.each do |vb|
              metrics["Virtual Servers/Throughput/In/#{@vs_names[index]}"] = (vb.value.to_f * 8)
              index += 1
            end
          end

          return metrics
        end
      end



      #
      # Gather VS Throughput Inbound (returns in bits)
      #
      def get_throughput_out(snmp = nil)
        metrics = { }
        index   = 0
        snmp    = snmp_manager unless snmp

        if snmp
          get_names(snmp) if @vs_names.empty?

          snmp.walk([OID_LTM_VIRTUAL_SERV_STAT_CLIENT_BYTES_OUT]) do |row|
            row.each do |vb|
              metrics["Virtual Servers/Throughput/Out/#{@vs_names[index]}"] = (vb.value.to_f * 8)
              index += 1
            end
          end

          return metrics
        end
      end



    end
  end
end

