# frozen_string_literal: true

module Elelem
  class Server
    # One browser tab: its session, and whether a turn is running in it.
    class Tab
      attr_reader :session

      def initialize(session)
        @session = session
        @lock = Mutex.new
        @busy = false
      end

      def terminal
        @session.output
      end

      def claim
        @lock.synchronize { @busy ? false : (@busy = true) }
      end

      # Runs a message or a /command, then tells the page the turn is done.
      def run(text)
        text.start_with?("/") ? command(text) : @session.turn(text)
      rescue StandardError, ScriptError => e
        terminal.say("Error: #{e.message}")
      ensure
        # done first, so the page cannot start a turn before this one says it ended.
        terminal.done
        @lock.synchronize { @busy = false }
      end

      private

      def command(line)
        name, args = line.delete_prefix("/").split(" ", 2)
        # /exit would stop the server for every tab. Closing the tab ends this one.
        return terminal.say("/exit is not available in the browser. Close the tab instead.") if name == "exit"
        return if @session.commands.run(name, args)

        terminal.say(@session.commands.names.join(" "))
      end
    end
  end
end
