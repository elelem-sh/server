# frozen_string_literal: true

RSpec.describe Elelem::Server::WebTerminal do
  subject { described_class.new }

  let(:events) { subject.subscribe }

  before { events }

  def drain(queue = events)
    [].tap { |collected| collected << queue.pop until queue.empty? }
  end

  describe "#interactive?" do
    it { expect(subject).to be_interactive }
  end

  describe "#say" do
    it "emits content" do
      subject.say("hello")
      expect(drain).to eq([{ type: "content", text: "hello" }])
    end

    it "ignores blank text" do
      subject.say("  ")
      subject.say(nil)
      expect(drain).to be_empty
    end

    it "strips ANSI colour codes meant for a terminal" do
      subject.say("+ \e[36mexecute\e[0m(...)")
      expect(drain).to eq([{ type: "content", text: "+ execute(...)" }])
    end

    it "accepts the as: keyword like Terminal#say" do
      subject.say("hello", as: :markdown)
      expect(drain).to eq([{ type: "content", text: "hello" }])
    end
  end

  describe "#thinking" do
    it "emits a thinking event" do
      subject.thinking("pondering")
      expect(drain).to eq([{ type: "thinking", text: "pondering" }])
    end
  end

  describe "#display_file" do
    it "emits the file's contents" do
      Tempfile.create do |file|
        file.write("contents")
        file.flush
        subject.display_file(file.path, fallback: "fallback")
        expect(drain).to eq([{ type: "content", text: "contents" }])
      end
    end

    it "emits the fallback when the file is missing" do
      subject.display_file("/no/such/file.rb", fallback: "contents")
      expect(drain).to eq([{ type: "content", text: "contents" }])
    end

    it "emits the fallback when the file is not valid UTF-8" do
      Tempfile.create do |file|
        file.binmode
        file.write("\xFF\xFE\x00\x01")
        file.flush
        subject.display_file(file.path, fallback: "contents")
        expect(drain).to eq([{ type: "content", text: "contents" }])
      end
    end
  end

  describe "#done" do
    it "emits a turn boundary" do
      subject.done
      expect(drain).to eq([{ type: "done" }])
    end
  end

  describe "#waiting" do
    it "is a no-op" do
      subject.waiting
      expect(drain).to be_empty
    end
  end

  describe "multiple subscribers" do
    it "every subscriber receives every event" do
      other = subject.subscribe
      subject.say("broadcast")
      expect(drain).to eq([{ type: "content", text: "broadcast" }])
      expect(drain(other)).to eq([{ type: "content", text: "broadcast" }])
    end

    it "stops delivering after unsubscribe" do
      subject.unsubscribe(events)
      subject.say("gone")
      expect(drain).to be_empty
    end
  end

  describe "#ask" do
    it "emits a prompt and blocks until answered" do
      thread = Thread.new { subject.ask("Allow?") }
      expect(events.pop).to eq({ type: "prompt", text: "Allow?" })
      subject.answer("n")
      expect(thread.value).to eq("n")
    end
  end
end
