RSpec.describe Nstance::Drivers::DockerAPI::AttachDriver do
  let(:instance) { @instance = create_instance }
  after { @instance&.stop }

  def create_instance(*args)
    Nstance::Instance.new(described_class.new(*args))
  end

  include_examples :shell_commands
  include_examples :files_and_archives
  include_examples :thread_safety
  # include_examples :stdin # not supported
  include_examples :isolation
  include_examples :resource_limiting

  describe "reconnecting" do
    it "recreates the container automatically if removed" do
      instance.run "echo a > foo"
      instance.driver.container.remove(force: true)
      result = instance.run "ls"
      expect(result.log).to_not include("foo")
    end
  end
end
