RSpec.shared_examples :resource_limiting do
  describe "timing out long commands" do
    it "returns a result with a timeout status" do
      result = instance.run("sleep 1", timeout: 0.1)
      expect(result.status).to eq :timeout
    end
  end

  describe "limiting output" do
    it "kills a command if it generates too much output" do
      result = instance.run("while true; do printf a; done", output_limit: 10)
      expect(result.status).to eq :output_limit_exceeded
      expect(result.log).to eq ("a" * 10) + "\n"
    end
  end

  describe "limiting memory" do
    pending
  end

  describe "limiting disk usage" do
    pending
  end
end
