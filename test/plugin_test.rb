require 'test_helper.rb'
class PluginTest < Test::Unit::TestCase

  context "Plugin" do

    setup do
      NewRelic::F5Plugin
      NewRelic::Plugin::Config.config_yaml = <<-EOF
newrelic:
  license_key: 'test_license_key'
  verbose: 0
  host: "localhost"
agents:
  f5:
    -
      name:           'My F5 LTM'
      hostname:       'my-f5'
      port:           161
      snmp_community: 'public'
      EOF
      NewRelic::Plugin::Setup.install_agent :f5, NewRelic::F5Plugin
    end

    should "create a run" do
      # The run loop is stubbed out so this just verifies the agent initializes correctly.
      NewRelic::Plugin::Run.any_instance.expects :setup_from_config
      NewRelic::Plugin::Run.any_instance.expects :loop_forever
      NewRelic::F5Plugin.run
    end

    # This mimics NewRelic::Plugin::Run.setup_and_run except for the loop_forever part
    context "run" do
      setup do
        NewRelic::Plugin::Run.any_instance.stubs :loop_forever
        @run = NewRelic::Plugin::Run.new
        @run.setup_from_config
        agents = @run.configured_agents
        assert_equal 1, agents.size
        @agent = agents.first
      end

      should "have one configured agent" do
        assert_equal "My F5 LTM", @agent.name
      end

      #context "test db" do
      #  setup do
      #    # Setup a test database
      #    @client = Mysql2::Client.new :host => 'localhost', :username => 'root'
      #    @client.query "create database nr_mysql_plugin" rescue nil
      #    @client.query "create table nr_mysql_plugin.example (id int)"
      #    @client.query "create table nr_mysql_plugin.ignored (id int)"
      #    @client.query "insert into nr_mysql_plugin.example values (1),(2),(3),(4),(5)"
      #  end
      #  teardown do
      #    @client.query "drop database nr_mysql_plugin" rescue nil
      #  end
      #  should "get table stats" do
      #    schemas = @agent.mysql_table_stats
      #    assert_equal 1, schemas.size
      #    tables = schemas['nr_mysql_plugin']
      #    assert_equal 1, tables.size
      #    rec = tables.first
      #    assert_equal "example", rec.name
      #    assert_equal 5, rec.rows
      #  end
      #  should "poll" do
      #    # This stubs out the remote connection--we're not testing the plugin agent here
      #    NewRelic::Plugin::DataCollector.any_instance.stubs :process
      #    @agent.run 60 # seconds
      #  end
      #end

    end

  end

end

