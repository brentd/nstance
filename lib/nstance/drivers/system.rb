require "open3"

module Nstance
  module Drivers
    module System
      # This driver executes commands directly on the host machine. It is
      # "unsafe" in the sense that using it to execute arbitrary shell commands
      # in a production environment is equivalent to shelling out arbitrary
      # commands to the host machine any other way (i.e. a bad idea). It is
      # intended only to demonstrate the simplest version of a driver, and as a
      # sort of benchmark for the test suite.
      class Driver
        def initialize(*)
          @dir = Pathname(Dir.mktmpdir)
        end

        def run(command, emitter)
          Thread.new do
            out, err, _ = Open3.capture3(command.render, chdir: @dir)
            emitter.receive_data(:stdout, out)
            emitter.receive_data(:stderr, err)
          end
          emitter
        end

        def stop
          @dir.rmtree
        end
      end
    end
  end
end
