require "bundler/setup"
require "nstance"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }
Dir[File.join(__dir__, "**/*_examples.rb")].each { |f| require f }

module IntegrationExampleGroup
  def self.included(group)
    Dir[File.join(__dir__, "integration/shared_examples/**/*.rb")].each { |f| require f }
  end
end

Thread.abort_on_exception = true

# Nstance.log.level = :debug

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.define_derived_metadata(:file_path => %r{integration}) do |metadata|
    metadata[:type] = :integration
  end
  config.include IntegrationExampleGroup, type: :integration
  config.include TarballHelper, type: :integration
end
