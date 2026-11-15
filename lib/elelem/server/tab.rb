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

      # Busy tabs, and tabs with a page open or seen in the last minute (an
      # EventSource that is reconnecting), keep their place.
      def idle?(now = Process.clock_gettime(Process::CLOCK_MONOTONIC), grace: 60)
        !@lock.synchronize { @busy } && terminal.subscribers.zero? && now - terminal.last_seen > grace
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
        # /exit would stop the server, and /reload would reload plugins under
        # every other tab. Restart elelem-server instead.
        if %w[exit reload].include?(name)
          return terminal.say("/#{name} is not available in the browser. Restart elelem-server instead.")
        end
        return if @session.commands.run(name, args)

        terminal.say(@session.commands.names.join(" "))
      end
    end
  end
end
