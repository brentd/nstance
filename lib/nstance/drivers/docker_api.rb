require "docker"

module Nstance
  module Drivers
    module DockerAPI
      require "nstance/drivers/docker_api/excon/socket_hijack"
      require "nstance/drivers/docker_api/attach_log_parser"
      require "nstance/drivers/docker_api/container_manager"
      require "nstance/drivers/docker_api/attach_driver"
      require "nstance/drivers/docker_api/exec_driver"

      ::Excon.defaults[:middlewares].unshift Excon::SocketHijack
    end
  end
end
