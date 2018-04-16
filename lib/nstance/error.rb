module Nstance
  class Error < StandardError; end

  class TimeoutError < Error
    attr_reader :message

    def initialize(timeout)
      @message = "Command did not complete before timeout (#{timeout}s)"
    end
  end
end
