RSpec.describe Nstance::Drivers::DockerAPI::AttachLogParser do
  let(:parser) { described_class.new }

  it "parses messages from both stdout and stderr" do
    raw_text = "\x01\x00\x00\x00\x00\x00\x00\x01a\x02\x00\x00\x00\x00\x00\x00\x01b"
    expect(parser.parse raw_text).to eq [
      [:stdout, "a"],
      [:stderr, "b"]
    ]
  end

  it "keeps a buffer when receiving partial headers" do
    expect(parser.parse "\x01\x00\x00").to eq nil
    expect(parser.parse "\x00\x00\x00").to eq nil
    expect(parser.parse "\x00\x01a").to eq [
      [:stdout, "a"]
    ]
  end

  it "keeps a buffer when receiving partial data" do
    expect(parser.parse "\x01\x00\x00\x00\x00\x00\x00\x02a").to eq nil
    expect(parser.parse "a").to eq [
      [:stdout, "aa"]
    ]
  end

  it "raises an error if extra data is present inbtetween headers" do
    parser.parse "\x01\x00\x00\x00\x00\x00\x00\x02aa"
    expect {
      parser.parse "nooo\x01\x00\x00\x00\x00\x00\x00\x03foo"
    }.to raise_error(described_class::InvalidHeaderError)
  end

  it "can handle a large amount of data" do
    size = 10_000
    data = "a" * size
    hex = [size].pack("N")
    header = "\x01\x00\x00\x00#{hex}"

    expect(parser.parse header + data).to eq [
      [:stdout, data]
    ]
  end

  it "can handle a large amount of data parsed in chunks" do
    size = 10_000
    data = "a" * size
    hex = [size].pack("N")
    header = "\x01\x00\x00\x00#{hex}"

    chunk_size = 4096
    chunks = (header + data).scan(/.{1,#{chunk_size}}/)
    messages = chunks.map { |chunk| parser.parse chunk }
    expect(messages.last).to eq [
      [:stdout, data]
    ]
  end
end
