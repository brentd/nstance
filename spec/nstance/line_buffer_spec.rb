RSpec.describe Nstance::LineBuffer do
  let(:buffer) { Nstance::LineBuffer.new }

  it "yields for each line in a string" do
    buffer = Nstance::LineBuffer.new

    expect { |b|
      buffer.parse("foo\nbar\nbaz\n", &b)
    }.to yield_successive_args("foo\n", "bar\n", "baz\n")
  end

  it "buffers lines until they have been terminated" do
    buffer = Nstance::LineBuffer.new

    expect { |b|
      buffer.parse("hello ", &b)
      buffer.parse("world\nwelcome", &b)
      buffer.parse(" to internet", &b)
      buffer.parse("\n", &b)
    }.to yield_successive_args("hello world\n", "welcome to internet\n")
  end

  it "yields blank lines as one line containing the delimiter" do
    expect { |b|
      buffer.parse("hello\n\n\n", &b)
      buffer.parse("world\n\n", &b)
    }.to yield_successive_args("hello\n", "\n", "\n", "world\n", "\n")
  end

  it "handles \r\n terminated lines" do
    buffer = Nstance::LineBuffer.new

    expect { |b|
      buffer.parse("hello ", &b)
      buffer.parse("world\r\nwelcome", &b)
      buffer.parse(" to internet", &b)
      buffer.parse("\r\n", &b)
    }.to yield_successive_args("hello world\r\n", "welcome to internet\r\n")
  end
end
