RSpec.shared_examples :stdin do
  describe "stdin support" do
    let(:queue) { Queue.new }
    let(:instance) { @instance = create_instance(image: "ruby:latest") }

    it "forwards stdin to a running program" do
      script = <<~RUBY
        print "name: "
        puts "hello, \#{gets}"
      RUBY

      instance.run("ruby file.rb", timeout: 1, files: {"file.rb" => script}) do |run|
        run.on_chunk do |stream, chunk|
          if chunk == "name: "
            run << "DHH\n"
          end
        end
        run.on_complete do |result|
          queue << result
        end
      end

      result = queue.pop
      expect(result.log).to include("hello, DHH\n")
    end
  end
end
