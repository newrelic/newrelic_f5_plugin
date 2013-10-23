## This is the rakegem gemspec template. Make sure you read and understand
## all of the comments. Some sections require modification, and others can
## be deleted if you don't need them. Once you understand the contents of
## this file, feel free to delete any comments that begin with two hash marks.
## You can find comprehensive Gem::Specification documentation, at
## http://docs.rubygems.org/read/chapter/20
Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'

  ## Leave these as is they will be modified for you by the rake gemspec task.
  ## If your rubyforge_project name is different, then edit it and comment out
  ## the sub! line in the Rakefile
  s.name              = 'newrelic_f5_plugin'
  s.version           = '1.0.5'
  s.date              = '2013-10-23'
  s.rubyforge_project = 'newrelic_f5_plugin'

  ## Make sure your summary is short. The description may be as long
  ## as you like.
  s.summary     = "New Relic F5 plugin"
  s.description = <<-EOF
This is the New Relic plugin for monitoring F5 devices developed by New Relic, Inc.
  EOF

  ## List the primary authors. If there are a bunch of authors, it's probably
  ## better to set the email to an email list or something. If you don't have
  ## a custom homepage, consider using your GitHub URL or the like.
  s.authors  = ["Jonathan Thurman"]
  s.email    = 'support@newrelic.com'
  s.homepage = 'http://newrelic.com'

  ## This gets added to the $LOAD_PATH so that 'lib/NAME.rb' can be required as
  ## require 'NAME.rb' or'/lib/NAME/file.rb' can be as require 'NAME/file.rb'
  s.require_paths = %w[lib]

  ## This sections is only necessary if you have C extensions.
  # s.require_paths << 'ext'
  # s.extensions = %w[ext/extconf.rb]

  ## If your gem includes any executables, list them here.
  s.executables = ["f5_monitor"]

  ## Specify any RDoc options here. You'll want to add your README and
  ## LICENSE files to the extra_rdoc_files list.
  s.rdoc_options = ["--charset=UTF-8",
                    "--main", "README.rdoc"]
  s.extra_rdoc_files = %w[README.rdoc LICENSE CHANGES]

  ## The newrelic_plugin needs to be installed.  Prior to public release, the
  # gem needs to be downloaded from git@github.com:newrelic-platform/newrelic_plugin.git
  # and built using the "rake build" command
  s.add_dependency('newrelic_plugin', "~> 1.3.0")
  s.add_dependency('snmp', ">= 1.1.0")

  s.post_install_message = <<-EOF
To get started with this plugin, create a working directory and do 
  f5_monitor -h
to find out how to install and run the plugin agent.
  EOF

  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
    CHANGES
    Gemfile
    LICENSE
    NOTES
    README.rdoc
    Rakefile
    bin/f5_monitor
    config/newrelic_plugin.yml
    lib/newrelic_f5_plugin.rb
    lib/newrelic_f5_plugin/agent.rb
    lib/newrelic_f5_plugin/device.rb
    lib/newrelic_f5_plugin/nodes.rb
    lib/newrelic_f5_plugin/pools.rb
    lib/newrelic_f5_plugin/util.rb
    lib/newrelic_f5_plugin/virtuals.rb
    newrelic_f5_plugin.gemspec
    test/f5_monitor_test.rb
    test/nodes_test.rb
    test/plugin_test.rb
    test/test_helper.rb
  ]
  # = MANIFEST =

  ## Test files will be grabbed from the file list. Make sure the path glob
  ## matches what you actually use.
  s.test_files = s.files.select { |path| path =~ /^test\/test_.*\.rb/ }
end
