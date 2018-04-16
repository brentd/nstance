module Nstance
  module Drivers
    module DockerAPI
      module Excon
        # This middleware allows us to hijack a HTTP request's socket so we can
        # read and write to it directly.
        class SocketHijack < ::Excon::Middleware::Base
          def response_call(datum)
            return @stack.response_call(datum) unless datum[:hijack]

            # Trick Excon's response parser into not attempting to read the
            # response body, or it would block forever.
            datum[:method] = "CONNECT"

            res = @stack.response_call(datum)

            # Set the raw Socket object on the response so we can access it.
            socket     = datum[:connection].send(:socket)
            raw_socket = socket.instance_variable_get(:@socket)
            datum[:response][:socket] = raw_socket

            # Don't allow Excon to close or reuse this socket. The responsibility
            # of closing the socket is now on the caller.
            datum[:connection].send(:sockets).delete_if { |k,v| v == socket }

            if Proc === datum[:hijack]
              datum[:hijack].call(raw_socket)
            end

            res
          end
        end
      end
    end
  end
end
