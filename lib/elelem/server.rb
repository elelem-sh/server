# frozen_string_literal: true

require "elelem"
require "json"
require "uri"
require "webrick"

require_relative "server/version"
require_relative "server/web_terminal"

module Elelem
  class Server
    INDEX = File.read(File.expand_path("server/index.html", __dir__))
    LOCAL_HOSTS = %w[localhost 127.0.0.1 [::1]].freeze

    def self.serve(provider: "stub", port: 4567, address: "127.0.0.1", toolbox: Toolbox.new)
      llm_provider = Config.build_provider(provider)
      web_terminal = WebTerminal.new
      agent = Agent.new(llm_provider, toolbox: toolbox, output: web_terminal)
      session = Session.new(agent, input: web_terminal)
      Config.apply(session)
      new(session, port: port, address: address).start
    end

    def initialize(session, port: 4567, address: "127.0.0.1")
      @session = session
      @port = port
      @address = address
      @terminal = session.output
      @lock = Mutex.new
      @busy = false
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
      $stdout.puts "elelem v#{VERSION} listening on http://#{url_host}:#{@port}"
      server.start
    end

    private

    # The agent can run commands, so only this machine's own pages may drive it.
    # A Host check stops DNS rebinding; JSON plus a matching Origin stops a
    # cross-site form or fetch.
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
      return false unless local_hosts.include?(host.sub(/:\d+\z/, ""))
      return true unless req.request_method == "POST"

      json?(req) && same_origin?(req["Origin"], host)
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

    def events(_req, res)
      res.content_type = "text/event-stream"
      res["Cache-Control"] = "no-cache"
      res.chunked = true
      res.body = ->(out) { stream(out) }
    end

    def stream(out)
      events = @terminal.subscribe
      loop do
        out.write("data: #{JSON.dump(events.pop)}\n\n")
      end
    rescue IOError, Errno::EPIPE, Errno::ECONNRESET
      nil
    ensure
      @terminal.unsubscribe(events)
    end

    # One turn at a time: two at once would interleave one conversation.
    def message(req, res)
      text = JSON.parse(req.body)["text"].to_s
      return busy(res) unless claim_turn

      Thread.new do
        @session.turn(text)
      rescue StandardError => e
        @terminal.say("Error: #{e.message}")
      ensure
        # done first, so a page cannot start a turn before this one says it ended.
        @terminal.done
        release_turn
      end
      res.status = 204
    end

    def claim_turn
      @lock.synchronize { @busy ? false : (@busy = true) }
    end

    def release_turn
      @lock.synchronize { @busy = false }
    end

    def busy(res)
      res.status = 409
      res.body = "busy"
    end

    def answer(req, res)
      body = JSON.parse(req.body)
      @terminal.answer(body["id"].to_i, body["text"].to_s)
      res.status = 204
    end
  end
end
