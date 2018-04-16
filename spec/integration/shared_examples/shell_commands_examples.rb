RSpec.shared_examples :shell_commands do
  describe "running simple shell commands" do
    it "returns the result of a simple echo" do
      result = instance.run("echo foo")
      expect(result.log).to eq "foo\n"
    end

    it "can handle arbitrary quotes in the command" do
      result = instance.run %(echo "I've got a \\"cool look\\"")
      expect(result.log).to eq %(I've got a "cool look"\n)
    end

    it "correctly logs newlines" do
      result = instance.run %(printf "\n\nhello\nworld\n\n\n")
      expect(result.log).to eq "\n\nhello\nworld\n\n\n"
    end

    it "knows the exit status of a successful command" do
      result = instance.run("echo foo")
      expect(result.status).to eq 0
    end

    it "knows the exit status of a command exiting with a non-zero status" do
      result = instance.run("exit 101")
      expect(result.log).to eq ""
      expect(result.status).to eq 101
    end

    it "can handle commands joined by &&" do
      result = instance.run("echo foo1 && echo foo2")
      expect(result.log).to eq "foo1\nfoo2\n"
      expect(result.status).to eq 0
      result = instance.run("echo foo1 && false && echo foo2")
      expect(result.status).to eq 1
    end

    it "can run commands in a specific directory" do
      result = instance.run("pwd", dir: "/etc")
      expect(result.log).to eq "/etc\n"
      result = instance.run("pwd", dir: "/tmp")
      expect(result.log).to eq "/tmp\n"
    end
  end
end
