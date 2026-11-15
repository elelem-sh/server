# frozen_string_literal: true

RSpec.describe Elelem::Server, "request guard" do
  subject(:server) { described_class.new(session, port: 4567, token: "secret") }

  let(:session) { double("session", output: double("terminal")) }

  def request(method: "GET", host: "127.0.0.1:4567", query: {}, x_elelem_token: "secret", **headers)
    headers = headers.merge(x_elelem_token: x_elelem_token).compact
    fields = { "Host" => host }.merge(headers.transform_keys { |k| k.to_s.split("_").map(&:capitalize).join("-") })
    double("request", request_method: method, query: query, "[]": nil).tap do |req|
      fields.each { |name, value| allow(req).to receive(:[]).with(name).and_return(value) }
    end
  end

  def allowed?(req) = server.send(:allowed?, req)

  it "refuses a request without the token" do
    expect(allowed?(request(x_elelem_token: nil))).to be false
    expect(allowed?(request(x_elelem_token: "guess"))).to be false
  end

  it "takes the token from the query string, for the first page load and EventSource" do
    expect(allowed?(request(x_elelem_token: nil, query: { "token" => "secret" }))).to be true
  end

  it "makes a new token for each server" do
    expect(described_class.new(session).token).not_to eq(described_class.new(session).token)
  end

  it "binds to 127.0.0.1 by default" do
    expect(server.instance_variable_get(:@address)).to eq("127.0.0.1")
  end

  it "serves the page to localhost, 127.0.0.1 and [::1]" do
    %w[localhost:4567 127.0.0.1:4567 [::1]:4567].each { |host| expect(allowed?(request(host: host))).to be true }
  end

  it "answers a bound IPv6 address, which a Host header puts in brackets" do
    server = described_class.new(session, port: 4567, address: "2001:db8::5", token: "secret")

    expect(server.send(:allowed?, request(host: "[2001:db8::5]:4567"))).to be true
  end

  it "refuses another Host, which is what DNS rebinding sends" do
    expect(allowed?(request(host: "evil.example:4567"))).to be false
  end

  it "takes a JSON post from its own page" do
    req = request(method: "POST", content_type: "application/json; charset=utf-8", origin: "http://127.0.0.1:4567")

    expect(allowed?(req)).to be true
  end

  it "refuses a post that is not JSON, which a cross-site form can send" do
    expect(allowed?(request(method: "POST", content_type: "text/plain"))).to be false
  end

  it "refuses a post from another origin" do
    req = request(method: "POST", content_type: "application/json", origin: "https://evil.example")

    expect(allowed?(req)).to be false
  end
end
