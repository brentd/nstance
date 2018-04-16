module Nstance
  # Represents the result of `run` on an instance, including the output
  # and the exit status of the command.
  class Result
    attr_accessor :lines, :status, :error
    alias_method :exit_code, :status

    def initialize(lines = [], status = nil, error: nil)
      @lines  = lines
      @status = status
      @error  = error
    end

    def inspect
      log = "---\n" + lines.map { |(stream, msg)| "#{stream} | #{msg}" }.join + "---"
      if error
        log + " error: #{error.inspect}"
      else
        log + " exit status: #{status}"
      end
    end

    def stdout
      for_stream(:stdout)
    end

    def stderr
      for_stream(:stderr)
    end

    def timeout?
      status == :timeout
    end

    def output_limit_exceeded?
      status == :output_limit_exceeded
    end

    def success?
      status == 0
    end

    # Returns a string of combined stdout and stderr lines.
    #
    # Note: this is not a true log of the output since we're working with full
    # lines - in reality, lines from stdout and stderr may have interleaved.
    def log
      lines.map { |stream, line| line }.join.force_encoding("UTF-8")
    end

    def to_s
      log
    end

    def for_stream(name)
      out = "".force_encoding("UTF-8")
      lines.each { |stream, line| out << line if stream == name }
      out
    end
  end
end
