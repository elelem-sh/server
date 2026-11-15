# frozen_string_literal: true

require "elelem"
require "json"
require "openssl"
require "securerandom"
require "uri"
require "webrick"

require_relative "server/version"
require_relative "server/web_terminal"
require_relative "server/tab"

module Elelem
  class Server
    INDEX = File.read(File.expand_path("server/index.html", __dir__))
    LOCAL_HOSTS = %w[localhost 127.0.0.1 [::1]].freeze

    MAX_TABS = 16
    TAB_ID = /\A[\w-]{1,64}\z/

    # Each browser tab gets its own session, built on its first request.
    def self.serve(provider: "stub", port: 4567, address: "127.0.0.1")
      Config.build_provider(provider) # fail at start, not on the first page load
      new(-> { session_for(provider) }, port: port, address: address).start
    end

    def self.session_for(provider)
      terminal = WebTerminal.new
      agent = Agent.new(Config.build_provider(provider), toolbox: Toolbox.new, output: terminal)
      Session.new(agent, input: terminal).tap { |session| Config.apply(session) }
    end

    attr_reader :token

    def initialize(build_session, port: 4567, address: "127.0.0.1", token: SecureRandom.hex(16))
      @build_session = build_session
      @port = port
      @address = address
      @token = token
      @tabs = {}
      @tabs_lock = Mutex.new
    end

    def start
      server = WEBrick::HTTPServer.new(
        Port: @port,
        BindAddress: @address,
        Logger: WEBrick::Log.new(File::NULL),
        AccessLog: []
      )
      %i[index events message answer].each do |name|
        server.mount_proc(name == :index ? "/" : "/#{name}", &guarded(name))
      end

      trap("INT") { server.shutdown }
      $stdout.puts "elelem v#{VERSION} listening on http://#{url_host}:#{@port}/?token=#{@token}"
      $stdout.flush # the URL carries the token; it must show even when stdout is a file
      server.start
    end

    private

    # The agent can run commands, so only this machine's own pages may drive it.
    # The token, printed at start, keeps out other users and programs on the
    # machine. A Host check stops DNS rebinding; JSON plus a matching Origin
    # stops a cross-site form or fetch.
    def guarded(name)
      handler = method(name)
      lambda do |req, res|
        next handler.call(req, res) if allowed?(req)

        res.status = 403
        res.body = "forbidden"
      end
    end

    def allowed?(req)
      host = req["Host"].to_s
      return false unless token?(req) && local_hosts.include?(host.sub(/:\d+\z/, ""))
      return true unless req.request_method == "POST"

      json?(req) && same_origin?(req["Origin"], host)
    end

    # A header from the page's fetch calls; the query string for the first page
    # load and for EventSource, which cannot set headers.
    def token?(req)
      given = req["X-Elelem-Token"] || req.query["token"]
      given.is_a?(String) && OpenSSL.secure_compare(given, @token)
    end

    def local_hosts
      LOCAL_HOSTS + [url_host]
    end

    # URLs and Host headers put an IPv6 address in brackets.
    def url_host
      @address.include?(":") ? "[#{@address}]" : @address
    end

    def json?(req)
      req["Content-Type"].to_s.split(";").first.to_s.strip.casecmp?("application/json")
    end

    def same_origin?(origin, host)
      return true if origin.nil?

      uri = URI(origin)
      authority = uri.port == uri.default_port ? uri.host : "#{uri.host}:#{uri.port}"
      authority == host
    rescue URI::InvalidURIError
      false
    end

    def index(_req, res)
      res.content_type = "text/html; charset=utf-8"
      res.body = INDEX
    end

    def events(req, res)
      tab = tab_for(req) or return no_tab(res)

      res.content_type = "text/event-stream"
      res["Cache-Control"] = "no-cache"
      res.chunked = true
      res.body = ->(out) { stream(tab.terminal, out) }
    end

    def stream(terminal, out)
      events = terminal.subscribe
      loop do
        out.write("data: #{JSON.dump(events.pop)}\n\n")
      end
    rescue IOError, Errno::EPIPE, Errno::ECONNRESET
      nil
    ensure
      terminal.unsubscribe(events)
    end

    # One turn at a time per tab: two at once would interleave one conversation.
    def message(req, res)
      tab = tab_for(req) or return no_tab(res)
      text = JSON.parse(req.body)["text"].to_s
      return busy(res) unless tab.claim

      Thread.new { tab.run(text) }
      res.status = 204
    end

    def busy(res)
      res.status = 409
      res.body = "busy"
    end

    def answer(req, res)
      tab = tab_for(req) or return no_tab(res)
      body = JSON.parse(req.body)
      tab.terminal.answer(body["id"].to_i, body["text"].to_s)
      res.status = 204
    end

    # The page sends its tab id as a header, or in the query for EventSource.
    def tab_for(req)
      id = req["X-Elelem-Tab"] || req.query["tab"]
      return unless id.is_a?(String) && id.match?(TAB_ID)

      @tabs_lock.synchronize do
        @tabs[id] ||= (Tab.new(@build_session.call) if @tabs.size < MAX_TABS)
      end
    end

    def no_tab(res)
      res.status = 400
      res.body = "missing tab, or too many tabs (#{MAX_TABS})"
    end
  end
end
