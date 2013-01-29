require 'test_helper.rb'
class F5MonitorTest < Test::Unit::TestCase

  context "f5_monitor" do

    setup do
      @verbose = $VERBOSE
      $VERBOSE = nil
      @file = File.expand_path("../../bin/f5_monitor", __FILE__)
    end

    teardown do
      $VERBOSE = @verbose
    end

    should "show help" do
      ::ARGV = %w[-h]
      load @file
    end

    should "run" do
      ::ARGV = %w[run]
      NewRelic::F5Plugin.expects :run
      load @file
    end

    should "install" do
      ::ARGV = %w[install --license LICENSE_KEY]
      FileUtils.expects :mkdir_p
      File.expects :open
      load @file
    end
  end

end

