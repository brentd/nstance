RSpec.describe Nstance::RunEmitter do
  subject { described_class.new(command) }
  let(:command) { double(:command, eof_regexp: /__EOF__\n/, output_limit: 1000, uid: "abc123")}

  describe "#on" do
    it "allows subscribing to events" do
      expect { |block|
        subject.on(:foo, &block)
        subject.send :emit, :foo, "hello"
      }.to yield_with_args("hello")
    end
  end

  describe "#receive_data events" do
    describe ":line" do
      it "emits lines received" do
        expect { |block|
          subject.on(:line, &block)
          subject.receive_data(:stdout, "hello\nworld\n")
        }.to yield_successive_args(
          [:stdout, "hello\n"],
          [:stdout, "world\n"]
        )
      end

      it "emits lines received with their respective stream" do
        expect { |block|
          subject.on(:line, &block)
          subject.receive_data(:stdout, "hello\n")
          subject.receive_data(:stderr, "world\n")
        }.to yield_successive_args(
          [:stdout, "hello\n"],
          [:stderr, "world\n"]
        )
      end

      it "emits only full lines" do
        expect { |block|
          subject.on(:line, &block)
          subject.receive_data(:stdout, "hello ")
          subject.receive_data(:stdout, "world\n")
          subject.receive_data(:stdout, "ignored")
        }.to yield_successive_args(
          [:stdout, "hello world\n"],
        )

        expect { |block|
          subject.on(:line, &block)
          subject.receive_data(:stdout, "foo")
        }.to_not yield_control
      end

      it "does not emit the EOF line" do
        expect { |block|
          subject.on(:line, &block)
          subject.receive_data(:stdout, "hello ")
          subject.receive_data(:stdout, "world\n")
          subject.receive_data(:stdout, "__EOF__\n")
        }.to yield_successive_args(
          [:stdout, "hello world\n"]
        )
      end

      context "when output_limit is exceeded" do
        it "emits the line up until the number of bytes specified by Command#output_limit" do
          allow(command).to receive(:output_limit) { 3 }

          expect { |block|
            subject.on(:line, &block)
            subject.receive_data(:stdout, "123456789\n")
            subject.receive_data(:stdout, "ignored\n")
          }.to yield_successive_args(
            [:stdout, "123\n"],
          )
        end
      end
    end

    context ":chunk" do
      it "emits data as it is received" do
        expect { |block|
          subject.on(:chunk, &block)
          subject.receive_data(:stdout, "hello ")
          subject.receive_data(:stdout, "world\n")
        }.to yield_successive_args(
          [:stdout, "hello "],
          [:stdout, "world\n"]
        )
      end

      it "does not emit the EOF line" do
        expect { |block|
          subject.on(:chunk, &block)
          subject.receive_data(:stdout, "hello ")
          subject.receive_data(:stdout, "world\n")
          subject.receive_data(:stdout, "__EOF__\n")
        }.to yield_successive_args(
          [:stdout, "hello "],
          [:stdout, "world\n"]
        )
      end

      context "when output_limit is exceeded" do
        before do
          allow(command).to receive(:output_limit) { 5 }
        end

        it "emits up until the exceeded bytes and emits a final newline" do
          expect { |block|
            subject.on(:chunk, &block)
            1.upto(10) do |n|
              subject.receive_data(:stdout, "#{n}")
            end
            subject.receive_data(:stdout, "ignored\n")
          }.to yield_successive_args(
            [:stdout, "1"],
            [:stdout, "2"],
            [:stdout, "3"],
            [:stdout, "4"],
            [:stdout, "5"],
            [:stdout, "\n"]
          )
        end
      end
    end

    context ":complete" do
      subject { described_class.new(command) }

      it "emits when the specified delimiter is reached" do
        expect(Nstance::Result).to receive(:new)
        expect { |block|
          subject.on(:complete, &block)
          subject.receive_data(:stdout, "hello\n__EOF__\n")
        }.to yield_control
      end

      it "does not include the EOF line in the result" do
        expect(Nstance::Result).to receive(:new).with([
          [:stdout, "hello\n"]
        ], anything)
        subject.receive_data(:stdout, "hello\n__EOF__\n")
      end

      it "emits complete even when the EOF is fragmented" do
        expect { |block|
          subject.on(:complete, &block)
          subject.receive_data(:stdout, "hello\n__E")
          subject.receive_data(:stdout, "OF__")
          subject.receive_data(:stdout, "\n")
        }.to yield_control
      end

      context "when output_limit is exceeded" do
        before do
          allow(command).to receive(:output_limit) { 3 }
        end

        it "emits the result with a truncated log" do
          expect(Nstance::Result).to receive(:new).with([
            [:stdout, "123\n"]
          ], anything)
          expect { |block|
            subject.on(:complete, &block)
            subject.receive_data(:stdout, "123456\n")
          }.to yield_control
        end
      end
    end
  end
end
