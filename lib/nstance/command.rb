require "rubygems/package"
require "erb"

module Nstance
  # Model representing a shell command and files to transport.
  class Command
    attr_reader :cmd, :archives, :files, :user, :timeout, :output_limit, :dir

    DEFAULT_TIMEOUT = 10
    DEFAULT_OUTPUT_LIMIT_IN_BYTES = 10_000

    def initialize(cmd, files: {}, archives: [], timeout: nil, output_limit: nil, user: nil, dir: nil)
      @cmd          = cmd.freeze
      @files        = files.freeze
      @archives     = archives.freeze
      @dir          = dir.freeze
      @output_limit = output_limit || DEFAULT_OUTPUT_LIMIT_IN_BYTES
      @timeout      = timeout || (DEFAULT_TIMEOUT if timeout.nil?)
      @user         = user
    end

    def self.template(path)
      file = File.read(File.expand_path("../#{path}", __FILE__))
      ERB.new(file, nil, "%")
    end

    TEMPLATES = {
      command: template("command.sh.erb")
    }

    def to_s
      cmd
    end

    def command_with_eof
      <<~SHELL
        /bin/sh -c "
          ($(echo #{escaped_base64_command} | $base64_decode))
          echo #{eof_delimiter}--\\$?
        "
      SHELL
    end

    def render(tty: false)
      result = TEMPLATES[:command].result(binding)
      result.gsub(/(^\s+)/, "") # Strip whitespace
    end

    def uid
      @uid ||= SecureRandom.hex(4)
    end

    def eof_delimiter
      "__EOF_#{uid}__"
    end

    def eof_regexp
      Regexp.new("#{eof_delimiter}--(?<exitstatus>.+)\n")
    end

    def base64_encode(data)
      Base64.strict_encode64(data)
    end

    def escaped_base64_command
      base64_encode(cmd)
    end

    def escaped_base64_archived_files
      tarball = StringIO.new

      Zlib::GzipWriter.wrap(tarball) do |gz|
        Gem::Package::TarWriter.new(gz) do |tar|
          @files.each do |filename, contents|
            tar.add_file_simple(filename, 0644, contents.bytes.length) { |io| io.write(contents) }
          end
        end
        gz.finish
      end

      tarball.rewind
      base64_encode(tarball.read)
    end
  end
end
