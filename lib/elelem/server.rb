# frozen_string_literal: true

require "elelem"
require "json"
require "webrick"

require_relative "server/version"
require_relative "server/web_terminal"

module Elelem
  class Server
    INDEX = File.read(File.expand_path("server/index.html", __dir__))

    def self.serve(provider: "stub", port: 4567, toolbox: Toolbox.new)
      llm_provider = Config.build_provider(provider)
      web_terminal = WebTerminal.new
      agent = Agent.new(llm_provider, toolbox: toolbox, output: web_terminal)
      session = Session.new(agent, input: web_terminal)
      Config.apply(session)
      new(session, port: port).start
    end

    def initialize(session, port: 4567, address: "0.0.0.0")
      @session = session
      @port = port
      @address = address
      @terminal = session.output
    end

    def start
      server = WEBrick::HTTPServer.new(
        Port: @port,
        BindAddress: @address,
        Logger: WEBrick::Log.new(File::NULL),
        AccessLog: []
      )
      server.mount_proc("/", &method(:index))
      server.mount_proc("/events", &method(:events))
      server.mount_proc("/message", &method(:message))
      server.mount_proc("/answer", &method(:answer))

      trap("INT") { server.shutdown }
      $stdout.puts "elelem v#{VERSION} listening on http://#{@address}:#{@port}"
      server.start
    end

    private

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

    def message(req, res)
      text = JSON.parse(req.body)["text"].to_s
      Thread.new do
        @session.turn(text)
      rescue StandardError => e
        @terminal.say("Error: #{e.message}")
      ensure
        @terminal.done
      end
      res.status = 204
    end

    def answer(req, res)
      body = JSON.parse(req.body)
      @terminal.answer(body["id"].to_i, body["text"].to_s)
      res.status = 204
    end
  end
end
