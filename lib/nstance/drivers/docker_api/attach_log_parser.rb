module Nstance
  module Drivers
    module DockerAPI
      # When using Docker's `/containers/:id/attach` endpoint, Docker will
      # multiplex the output of stdout and stderr to the connection as one
      # stream, where each chunk of output is prefixed with an 8-byte header:
      #
      #   header := [8]byte{STREAM_TYPE, 0, 0, 0, SIZE1, SIZE2, SIZE3, SIZE4}
      #
      # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/attach-to-a-container
      #
      # This class is responsible for parsing that output into messages of the
      # form:
      #
      #   [
      #     [:stdout, "hello"],
      #     [:stdout, "world!\n"],
      #     [:stderr, "oh no!"]
      #   ]
      #
      class AttachLogParser
        class InvalidHeaderError < StandardError; end

        STREAMS = {
          1 => :stdout,
          2 => :stderr
        }

        def initialize
          @buffer = ""
        end

        # Parse a string of data, returning an array of messages. Returns an
        # empty array if no messages were read to completion.
        def parse(chunk, &block)
          data = @buffer + chunk
          @buffer = ""
          messages = []

          until data.empty?
            header = data.slice!(0,8)
            if header.length < 8
              @buffer = header
              return
            end
            unless header[0..3] == "\x01\x00\x00\x00" || header[0..3] == "\x02\x00\x00\x00"
              raise InvalidHeaderError, "expected header, got: #{header.inspect}"
            end
            stream_int, length = header.unpack("CxxxN")

            message = data.slice!(0, length)
            if message.length < length
              @buffer = header + message
            else
              messages << [STREAMS[stream_int], message]
            end
          end

          if block_given?
            messages.each(&block)
          end

          messages if messages.any?
        end
      end
    end
  end
end
