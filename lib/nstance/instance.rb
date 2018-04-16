module Nstance
  # An Nstance::Instance represents an environment that can store files and run
  # shell commands, and is the main API of Nstance. Use the factory method
  # `Nstance.create` rather than instantiating this class directly unless you
  # have a good reason.
  #
  # The implementation details of how commands are executed are provided by
  # drivers. For example, using one of the DockerAPI drivers, files and shell
  # commands are sent to a Docker container.
  #
  # Driver instances are expected to respond to just two methods:
  #
  #   - `#run(command, emitter)`: expected to execute the command asynchronously.
  #   - `#stop` cleans up any resources used by the environment (e.g. a
  #     Docker container).
  #
  class Instance
    attr_reader :driver

    def initialize(driver)
      @driver = driver
    end

    def run(cmd, files: {}, archives: [], **options, &block)
      command = Command.new(cmd, files: files, archives: archives, **options)
      emitter = RunEmitter.new(command)

      Nstance.log.debug "Command #{command.uid} scheduled: #{cmd.inspect}"

      driver.run(command, emitter)

      if block_given?
        yield emitter
        emitter
      else
        emitter.wait
      end
    end

    def stop
      driver.stop
    end
  end
end
