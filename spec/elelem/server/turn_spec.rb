# frozen_string_literal: true

RSpec.describe Elelem::Server, "turns" do
  subject(:server) { described_class.new(session) }

  let(:gate) { Queue.new }
  let(:terminal) { double("terminal", done: nil, say: nil) }
  let(:session) do
    double("session", output: terminal).tap { |s| allow(s).to receive(:turn) { gate.pop } }
  end

  def post(text)
    res = Struct.new(:status, :body).new
    server.send(:message, double("request", body: JSON.generate(text: text)), res)
    res
  end

  it "refuses a second message while a turn runs, then takes the next one" do
    expect(post("one").status).to eq(204)
    expect(post("two").status).to eq(409)

    gate << :finish
    sleep 0.01 until server.instance_variable_get(:@busy) == false
    expect(post("three").status).to eq(204)
    gate << :finish
  end
end
