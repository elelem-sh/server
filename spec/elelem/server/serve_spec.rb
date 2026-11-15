# frozen_string_literal: true

RSpec.describe Elelem::Server, ".session_for" do
  it "builds a tab session with the demo provider" do
    session = described_class.session_for("demo")

    expect(session.turn("echo hi")).to start_with("exit 0")
  end
end
