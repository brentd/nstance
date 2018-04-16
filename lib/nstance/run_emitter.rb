require "shellwords"
require "rubygems/package"

module Nstance
  class RunEmitter
    attr_reader :command, :bytesize, :result

    def initialize(command)
      @command    = command
      @lines      = []
      @bytesize   = 0

      @line_buffers = {
        stdout: LineBuffer.new,
        stderr: LineBuffer.new
      }
    end

    def << data
      emit(:write, data)
    end

    def wait(timeout = nil)
      lock      = Mutex.new
      condition = ConditionVariable.new

      # Default the timeout to the command's timeout, but give the script a
      # chance to complete with its timeout instead of raising an error.
      timeout ||=  command.timeout && command.timeout + 5

      on_complete do
        lock.synchronize { condition.signal }
      end

      lock.synchronize { condition.wait(lock, timeout) }
      result || raise(TimeoutError, timeout)
    end

    def on(event, &block)
      listeners[event.to_sym].push block
    end

    def on_write(&block)
      on(:write, &block)
    end

    def on_chunk(&block)
      on(:chunk, &block)
    end

    def on_line(&block)
      on(:line, &block)
    end

    def on_complete(&block)
      on(:complete, &block)
    end

    def completed?
      !!@result
    end

    # Processes data received from a command execution, emitting events as
    # necessary. Also:
    #
    #   - Watches for the Command's EOF delimiter, to know when to mark this
    #     run as completed.
    #   - Honors the Command's `output_limit`, completing the run if the limit
    #     is exceeded.
    #
    def receive_data(stream, data)
      Nstance.log.debug "Command #{command.uid} received data: [#{stream}] #{data.inspect}"
      return if completed?

      total_bytes_received = @bytesize + data.bytesize
      limit_exceeded = total_bytes_received > command.output_limit

      if limit_exceeded
        remaining = command.output_limit - total_bytes_received
        data = data[0...remaining] + "\n"
        @bytesize += data.bytesize
      else
        @bytesize = total_bytes_received
      end

      chunk = data.sub(command.eof_regexp, "")
      emit(:chunk, stream, chunk) unless chunk.empty?

      @line_buffers[stream].parse(data) do |line|
        if status = parse_status_and_strip_eof(line)
          receive_line(stream, line) unless line.empty?
          complete(status)
        elsif limit_exceeded
          receive_line(stream, line) unless line.empty?
          complete(:output_limit_exceeded)
        else
          receive_line(stream, line)
        end
      end
    end

    def receive_error(ex)
      complete(ex)
    end

    def output_limit_exceeded?
      @result && @result.output_limit_exceeded?
    end

  private

    # Completes the run, emitting a Result with the given status.
    def complete(status)
      if Exception === status
        @result = Result.new(@lines, error: status)
      else
        @result = Result.new(@lines, status)
      end
      emit(:complete, @result)

      @lines = nil
      @line_buffers = nil
      @listeners = nil
    end

    def receive_line(stream, line)
      @lines << [stream, line]
      emit(:line, stream, line)
    end

    def parse_status_and_strip_eof(line)
      if match = command.eof_regexp.match(line)
        line.sub! command.eof_regexp, ''
        if match.names.include?("exitstatus")
          status = match[:exitstatus]
        end
        if status == "TIMEOUT"
          :timeout
        else
          status.to_i
        end
      end
    end

    def emit(event, *args)
      Nstance.log.debug "Command #{command.uid} event:#{event}, payload:#{args.inspect}"
      listeners[event].each { |cb| cb.call(*args) }
    end

    def listeners
      @listeners ||= Hash.new { |hash, key| hash[key] = [] }
    end
  end
end
