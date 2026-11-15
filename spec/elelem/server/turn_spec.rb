# frozen_string_literal: true

RSpec.describe Elelem::Server, "tabs and turns" do
  subject(:server) { described_class.new(-> { build.call }, token: "t") }

  let(:gate) { Queue.new }
  let(:sessions) { [] }
  let(:build) do
    lambda do
      terminal = double("terminal", done: nil, say: nil, subscribers: 0, last_seen: -1_000_000)
      double("session", output: terminal).tap do |s|
        allow(s).to receive(:turn) { gate.pop }
        sessions << s
      end
    end
  end

  def request(tab, text = "hi")
    double("request", body: JSON.generate(text: text), query: {}).tap do |req|
      allow(req).to receive(:[]).with("X-Elelem-Tab").and_return(tab)
    end
  end

  def post(tab, text = "hi")
    res = Struct.new(:status, :body).new
    server.send(:message, request(tab, text), res)
    res
  end

  def wait_idle(tab)
    sleep 0.01 until server.send(:tab_for, request(tab)).claim
    server.send(:tab_for, request(tab)).instance_variable_set(:@busy, false)
  end

  it "gives each tab its own session" do
    post("a")
    post("b")

    expect(sessions.size).to eq(2)
    2.times { gate << :finish }
  end

  it "refuses a second message in the same tab while its turn runs, then takes the next" do
    expect(post("a").status).to eq(204)
    expect(post("a").status).to eq(409)
    expect(post("b").status).to eq(204)

    2.times { gate << :finish }
    wait_idle("a")
    expect(post("a").status).to eq(204)
    gate << :finish
  end

  it "refuses a request without a tab id" do
    expect(post(nil).status).to eq(400)
  end

  it "frees an idle tab's place at the limit, but not a busy one's" do
    described_class::MAX_TABS.times { |i| post("t#{i}") }
    expect(post("one-more").status).to eq(400)

    gate << :finish
    sleep 0.01 until server.instance_variable_get(:@tabs).values.any?(&:idle?)
    expect(post("one-more").status).to eq(204)
    described_class::MAX_TABS.times { gate << :finish }
  end

  it "builds a new tab without holding up the others" do
    post("a")
    gate << :finish
    slow = Queue.new
    server.instance_variable_set(:@build_session, -> { slow.pop and build.call })
    Thread.new { server.send(:tab_for, request("slow")) }
    sleep 0.05

    expect(Timeout.timeout(1) { server.send(:tab_for, request("a")) }).not_to be_nil
    slow << :go
  end
end
