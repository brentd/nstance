require "securerandom"

module Nstance
  module Drivers
    module DockerAPI
      # This driver creates a container and executes commands on it using the
      # `/exec` endpoints. It has Docker allocate a TTY for each command, making
      # it suitable for commands that require interactivity via STDIN, at the
      # cost of a little bit of speed, since multiple HTTP requests are required
      # for each command execution.
      class ExecDriver
        attr_reader :uuid, :image

        def initialize(image: "busybox:latest")
          @uuid    = SecureRandom.uuid
          @image   = image
          @manager = ContainerManager.new(image, container_opts)
        end

        def run(command, emitter)
          Thread.new { perform(command, emitter) }
          emitter
        end

        def stop
          @manager.remove
        end

        def container
          @manager.container
        end

      private

        def container_opts
          {
            Image:       image,
            Cmd:         ["sh"],
            Labels:      {"nstance" => uuid},
            OpenStdin:   true,
            AttachStdin: true,
            "name" =>    "nstance_#{uuid}"
          }
        end

        def perform(command, emitter)
          attempt = 1
          cmd = command.render(tty: true)

          begin
            exec_cmd(cmd, emitter)
          rescue Docker::Error::DockerError, IOError => e
            (stop && retry) if (attempt += 1) <= 3
            emitter.receive_error(e)
          rescue => e
            emitter.receive_error(e)
          end
        end

        def exec_cmd(cmd, emitter)
          socket = create_and_start_exec(cmd)

          emitter.on_write { |data| socket << data }

          loop do
            chunk = socket.readpartial(4096)
            # When emulating a TTY, stdout and stderr are combined, so report
            # everything as stdout.
            emitter.receive_data(:stdout, chunk)
            break if emitter.completed?
          end
        ensure
          socket.close if socket
        end

        def create_and_start_exec(cmd)
          res = container.connection.post("/containers/#{container.id}/exec", {},
            body: {
              AttachStdin:  true,
              AttachStdout: true,
              AttachStderr: true,
              Tty:          true,
              Cmd:          ["sh", "-c", cmd]
            }.to_json)
          exec_instance = JSON[res]

          conn  = container.connection
          excon = ::Excon.new(conn.url, conn.options)

          res = excon.post(
            path: "/v#{Docker::API_VERSION}/exec/#{exec_instance["Id"]}/start",
            body: { Tty: true }.to_json,
            hijack: true
          )
          res[:socket]
        end
      end
    end
  end
end
