require "securerandom"

module Nstance
  module Drivers
    module DockerAPI
      class AttachDriver
        attr_reader :uuid, :image

        def initialize(image: "busybox:latest")
          @uuid    = SecureRandom.uuid
          @image   = image
          @manager = ContainerManager.new(image, container_opts)
          @parser  = AttachLogParser.new
          @lock    = Mutex.new
          @queue   = Array.new
        end

        def run(command, emitter)
          @lock.synchronize do
            @queue << [command, emitter]
            Thread.new { perform } if @queue.length == 1
          end
          emitter
        end

        def stop
          @manager.remove
          @socket.close if @socket
          @socket = nil
          true
        end

        def container
          @manager.container
        end

      private

        def container_opts
          {
            Image:     image,
            Cmd:       ["sh"],
            Labels:    {"nstance" => uuid},
            OpenStdin: true,
            StdinOnce: true,
            "name" =>  "nstance_#{uuid}"
          }
        end

        # Loops until all waiting commands have been completed.
        def perform
          loop do
            command, emitter = @lock.synchronize do
              return if @queue.empty?
              @queue.first
            end
            attempt = 1

            begin
              attach_read_loop(command, emitter)
            rescue Docker::Error::DockerError, IOError => e
              (stop && retry) if (attempt += 1) <= 3
              emitter.receive_error(e)
            rescue => e
              emitter.receive_error(e)
            ensure
              @queue.shift
            end
          end
        end

        def attach_read_loop(command, emitter)
          attach_if_needed

          @socket << command.render

          loop do
            chunk = @socket.readpartial(4096)

            @parser.parse(chunk) do |stream, data|
              emitter.receive_data(stream, data)
            end

            if emitter.completed?
              stop if emitter.output_limit_exceeded?
              break
            end
          end
        end

        def attach_if_needed
          return if @socket && !@socket.closed?

          conn = container.connection
          excon = ::Excon.new(conn.url, conn.options)

          res = excon.post(
            path: "/v#{Docker::API_VERSION}/containers/#{container.id}/attach",
            query: {
              stream: true,
              stdout: true,
              stdin:  true,
              stderr: true
            },
            hijack: true
          )

          @socket = res[:socket]
        end
      end
    end
  end
end
