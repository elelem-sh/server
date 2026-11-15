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
    it "emits a prompt with an id and blocks until answered with a matching id" do
      thread = Thread.new { subject.ask("Allow?") }
      event = events.pop
      expect(event).to include(type: "prompt", text: "Allow?")
      subject.answer(event[:id], "n")
      expect(thread.value).to eq("n")
    end

    it "ignores an answer for an id that isn't pending" do
      thread = Thread.new { subject.ask("Allow?") }
      event = events.pop
      subject.answer(event[:id] + 1, "n")
      subject.answer(event[:id], "y")
      expect(thread.value).to eq("y")
    end

    it "does not let an answer sent before any prompt pre-approve the next prompt" do
      subject.answer(1, "y")

      thread = Thread.new { subject.ask("Allow?") }
      event = events.pop
      subject.answer(event[:id], "n")

      expect(thread.value).to eq("n")
    end
  end

  it "replays a prompt still waiting for an answer to a page that subscribes again" do
    terminal = described_class.new
    asking = Thread.new { terminal.ask("Allow execute `ls`? [Y/n] > ") }
    sleep 0.01 until terminal.instance_variable_get(:@open).any?

    replay = terminal.subscribe.pop(timeout: 1)
    expect(replay).to include(type: "prompt", text: "Allow execute `ls`? [Y/n] > ")

    terminal.answer(replay[:id], "y")
    expect(asking.value).to eq("y")
    expect(terminal.subscribe.pop(timeout: 0.05)).to be_nil
  end

  it "numbers prompts across every terminal, so a rebuilt tab never reuses an id" do
    first = described_class.new
    second = described_class.new
    ids = [first, second].map do |terminal|
      Thread.new { terminal.ask("ok?") }
      sleep 0.01 until terminal.instance_variable_get(:@open).any?
      terminal.instance_variable_get(:@open).keys.first.tap { |id| terminal.answer(id, "y") }
    end

    expect(ids.uniq.size).to eq(2)
  end
end
