require "logger"

require "nstance/version"
require "nstance/error"
require "nstance/line_buffer"
require "nstance/command"
require "nstance/instance"
require "nstance/result"
require "nstance/run_emitter"
require "nstance/drivers/docker_api"
require "nstance/drivers/system"

module Nstance
  def self.create(driver: :docker_attach, **driver_opts)
    driver = case driver
      when :docker_attach
        Drivers::DockerAPI::AttachDriver.new(**driver_opts)
      when :docker_exec
        Drivers::DockerAPI::ExecDriver.new(**driver_opts)
      when :system
        Drivers::System::Driver.new(**driver_opts)
      else
        driver
      end

    instance = Instance.new(driver)

    if block_given?
      begin
        yield instance
      ensure
        instance&.stop
      end
    else
      instance
    end
  end

  def self.logger=(logger)
    @logger = logger
  end

  def self.log
    @logger ||= begin
      logger = Logger.new(STDOUT)
      logger.progname = "nstance"
      logger.level = :warn
      logger
    end
  end
end
