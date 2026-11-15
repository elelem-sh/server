# frozen_string_literal: true

RSpec.describe Elelem::Server::Tab do
  subject(:tab) { described_class.new(session) }

  let(:said) { [] }
  let(:terminal) { double("terminal", done: nil).tap { |t| allow(t).to receive(:say) { |text| said << text } } }
  let(:commands) { Elelem::Commands.new.tap { |c| c.register("ping", description: "Ping") { said << "pong" } } }
  let(:session) { double("session", output: terminal, commands: commands, turn: nil) }

  it "runs a slash command instead of sending it to the model" do
    tab.run("/ping")

    expect(said).to eq(["pong"])
    expect(session).not_to have_received(:turn)
  end

  it "lists the commands for an unknown one" do
    tab.run("/nope")

    expect(said).to eq(["/ping"])
  end

  it "does not let /exit stop the server" do
    tab.run("/exit")

    expect(said.first).to match(/not available in the browser/)
  end

  it "sends anything else to the model, and says when the turn is done" do
    tab.run("hello")

    expect(session).to have_received(:turn).with("hello")
    expect(terminal).to have_received(:done)
  end
end
