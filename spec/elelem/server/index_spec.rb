# frozen_string_literal: true

RSpec.describe "the web page" do
  let(:html) { Elelem::Server::INDEX }

  # The page once lived in a Ruby heredoc, which needed \\n. In a .html file
  # that is a literal backslash, so no reply rendered its line breaks.
  it "has no regex escaped for a Ruby string" do
    expect(html.scan(%r{\.replace\(/[^\n]*\\\\[nwsS*]})).to be_empty
  end

  it "turns line breaks into <br>" do
    expect(html).to include(".replace(/\\n/g, \"<br>\")")
  end
end
