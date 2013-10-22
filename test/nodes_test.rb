require 'test_helper.rb'
require 'snmp'

#
# Custom transport, based on the snmp test suite
#  https://github.com/hallidave/ruby-snmp/
#
class NodeTransport
  def initialize
  end

  def close
  end

  def send(data, host, port)
    @data = data
  end

  def recv(max_bytes)
    SNMP::Message.decode(@data).response.encode[0,max_bytes]
  end
end


class NodeTest < Test::Unit::TestCase

  include SNMP

  def setup
    @manager = Manager.new(:Transport => NodeTransport.new)
    @status  = {
      :empty => {
                  "Nodes/Monitor Status/checking"           => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/disabled"           => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/down"               => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/down-manual-resume" => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/forced-down"        => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/forced-up"          => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/inband"             => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/inband-down"        => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/irule-down"         => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/maint"              => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/unchecked"          => {:count=>0, :label=>"nodes"},
                  "Nodes/Monitor Status/up"                 => {:count=>0, :label=>"nodes"},
                },
    }
  end

  def teardown
    @manager.close
  end



  def test_init
    @nodes = NewRelic::F5Plugin::Nodes.new @manager
    assert_equal(@manager, @nodes.snmp_manager)
  end

  def test_get_status_default
    @nodes = NewRelic::F5Plugin::Nodes.new @manager
    @node_status = @nodes.get_status
    assert_equal(@node_status, @status[:empty])
  end

  def test_get_status_args
    @nodes = NewRelic::F5Plugin::Nodes.new @manager
    @node_status = @nodes.get_status @manager
    assert_equal(@node_status, @status[:empty])
  end
end

