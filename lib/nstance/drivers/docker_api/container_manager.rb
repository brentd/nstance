module Nstance
  module Drivers
    module DockerAPI
      class ContainerManager
        attr_reader :image, :container_opts

        def initialize(image, container_opts = {})
          @image          = image
          @container_opts = container_opts
          @lock           = Mutex.new
        end

        def container
          @container || @lock.synchronize do
            @container ||= begin
              container = create_container
              container.start
              container
            end
          end
        end

        def remove
          @lock.synchronize do
            if @container
              Nstance.log.debug "Removing container: #{container_opts}"

              begin
                @container.remove(force: true)
              rescue Docker::Error::NotFoundError
              ensure
                @container = nil
              end
            end
          end
        end

      private

        def create_container
          Nstance.log.debug "Creating container: #{container_opts}"
          Docker::Container.create(container_opts)
        rescue Docker::Error::NotFoundError => e
          if e.message =~ /No such image/
            Nstance.log.info "Pulling image: #{image}"
            Docker::Image.create(fromImage: image)
            retry
          else
            raise
          end
        end
      end
    end
  end
end
