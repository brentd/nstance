RSpec.shared_examples :isolation do
  describe "instance isolation" do
    it "uses the same filesystem for multiple runs" do
      instance.run "echo a > foo"
      expect(instance.run("cat foo").log).to eq "a\n"
      expect(instance.run("cat foo").log).to eq "a\n"
    end

    it "uses separate filesystems for separate instances" do
      instance2 = create_instance

      instance.run "echo a > /tmp/foo"
      instance2.run "echo b > /tmp/foo"

      expect(instance.run("cat /tmp/foo").log).to eq "a\n"
      expect(instance2.run("cat /tmp/foo").log).to eq "b\n"
    end
  end
end
