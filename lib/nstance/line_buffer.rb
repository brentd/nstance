module Nstance
  # A simple line buffer that buffers text until a delimiter, e.g. a newline, is
  # found.
  class LineBuffer
    def initialize(delimiter = "\n")
      @buffer = ""
      @delimiter = delimiter
    end

    def parse(chunk)
      chunk = @buffer + chunk
      @buffer = ""

      chunk.each_line(@delimiter) do |line|
        if line.end_with?(@delimiter)
          yield line
        else
          @buffer << line
        end
      end
    end
  end
end
