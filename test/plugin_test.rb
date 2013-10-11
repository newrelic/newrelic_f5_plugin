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
        assert_equal "my-f5", @agent.hostname
      end

    end

  end

end

