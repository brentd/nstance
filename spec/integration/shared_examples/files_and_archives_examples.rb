RSpec.shared_examples :files_and_archives do
  describe "sending files" do
    it "can store simple files in the container" do
      result = instance.run("cat foo.rb", files: {"foo.rb" => "puts 123"})
      expect(result.log).to eq "puts 123"
    end

    it "stores files that are writable by the user" do
      result = instance.run("echo wow >> foo.rb && cat foo.rb", files: {"foo.rb" => "puts 123"})
      expect(result.log).to eq "puts 123wow\n"
    end
  end

  describe "sending archives" do
    let(:tarball) { TarballHelper.from_hash({"foo.rb" => "puts 123\n"}) }

    it "can store an archive of files" do
      result = instance.run("cat foo.rb", archives: [tarball])
      expect(result.log).to eq "puts 123\n"
    end

    it "unpacks files that are writable by the user" do
      result = instance.run("echo wow >> foo.rb && cat foo.rb", archives: [tarball])
      expect(result.log).to eq "puts 123\nwow\n"
    end

    it "applies files after archives and overwrites existing files" do
      result = instance.run("cat foo.rb", files: {"foo.rb" => "overwritten"}, archives: [tarball])
      expect(result.log).to eq "overwritten"
    end

    it "can extract multiple archives to specific directories" do
      result = instance.run("cat foo/foo.rb", archives: [[tarball, "./foo"], [tarball, "./bar"]])
      expect(result.log).to eq "puts 123\n"
      result = instance.run("cat bar/foo.rb")
      expect(result.log).to eq "puts 123\n"
    end

    it "creates a destination directory that is writable by the user" do
      result = instance.run("echo hello > foo/bar/baz.txt && cat foo/bar/baz.txt", archives: [[tarball, "foo/bar"]])
      expect(result.log).to eq "hello\n"
    end
  end
end
