require "rubygems"

# Utility for generating gzipped tar archives (.tar.gz files) from a hash:
#
#   TarballHelper.from_hash({"foo.rb" => "puts 123", "bar.rb" => "hello"})
#
module TarballHelper
  def self.from_hash(files)
    io = StringIO.new
    io.binmode
    Zlib::GzipWriter.wrap(io) do |gz|
      Gem::Package::TarWriter.new(gz) do |tar|
        files.each do |path, contents|
          if contents.is_a?(Array)
            mode, file = contents
          else
            mode, file = [0644, contents]
          end
          tar.add_file_simple(path, mode, file.length) do |tar_io|
            tar_io.write(file)
          end
        end
      end
    end
    io.string
  end
end
