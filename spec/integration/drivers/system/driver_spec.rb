RSpec.describe Nstance::Drivers::System::Driver do
  let(:instance) { @instance = create_instance }
  after { @instance&.stop }

  def create_instance(*args)
    Nstance::Instance.new(described_class.new(*args)).tap do |instance|
      # Disable timeout for the system driver since the `timeout` command is not
      # included in macOS.
      def instance.run(cmd, timeout: false, **opts)
        super(cmd, timeout: timeout, **opts)
      end
    end
  end

  include_examples :shell_commands
  include_examples :files_and_archives
  include_examples :thread_safety
  # include_examples :stdin # not supported
  # include_examples :isolation # not supported
  # include_examples :resource_limiting # not supported
end
