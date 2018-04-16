RSpec.shared_examples :thread_safety do
  describe "thread safety" do
    let(:concurrency) { 10 }

    context "when using the synchronous API" do
      describe "multiple threads using one instance" do
        it "does not mix output" do
          Array.new(concurrency) { |n|
            Thread.new do
              result = instance.run("printf #{n}")
              expect(result.log).to eq "#{n}"
            end
          }.each(&:join)
        end
      end

      describe "multiple instances used by multiple respective threads" do
        it "processes commands independently" do
          Array.new(concurrency) { |n|
            Thread.new do
              instance = create_instance
              result = instance.run "sleep #{rand}; printf #{n}"
              expect(result.log).to eq "#{n}"
              instance.stop
            end
          }.each(&:join)
        end
      end
    end

    context "when using the asynchronous API" do
      let(:queue) { Queue.new }

      describe "multiple threads using one instance" do
        it "does not mix output and does not guarantee order" do
          Array.new(concurrency) { |n|
            instance.run("printf #{n}") do |runner|
              runner.on_complete do |result|
                queue << result
                expect(result.log).to eq "#{n}"
              end
            end
          }

          results = Array.new(concurrency) { queue.pop }
          expect(results.map(&:log)).to match_array ("0".."9").to_a
        end
      end
    end
  end
end
