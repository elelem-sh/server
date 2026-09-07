# frozen_string_literal: true

module Elelem
  class Server
    class WebTerminal
      def initialize
        @subscribers = []
        @mutex = Mutex.new
        @answers = Queue.new
      end

      def subscribe
        Queue.new.tap { |queue| @mutex.synchronize { @subscribers << queue } }
      end

      def unsubscribe(queue)
        @mutex.synchronize { @subscribers.delete(queue) }
      end

      def interactive?
        true
      end

      def quiet?
        false
      end

      def ask(prompt)
        emit("prompt", prompt)
        @answers.pop
      end

      def think(text)
        emit("thinking", text)
        nil
      end

      def say(text, markdown: false)
        emit("content", text)
      end

      def do(header)
        gap
        say header
      end

      def oops(error)
        say "\n  ✗ #{error.message}"
        Elelem.logger.warn("agent: #{error.message}\n#{error.backtrace.join("\n")}")
      end

      def print(text)
        emit("content", text)
      end

      def markdown(text)
        text
      end

      def display_file(path, fallback: nil)
        content = File.read(path)
        raise ArgumentError unless content.valid_encoding?

        say(content)
      rescue Errno::ENOENT, Errno::EISDIR, ArgumentError
        say(fallback || path)
      end

      def answer(text)
        @answers << text
      end

      def done
        broadcast(type: "done")
      end

      def waiting; end

      def gap; end

      def newline(n: 1); end

      private

      def emit(type, text)
        plain = text.to_s.gsub(/\e\[[0-9;]*[a-zA-Z]/, "")
        return if plain.strip.empty?

        broadcast(type: type, text: plain)
      end

      def broadcast(event)
        @mutex.synchronize { @subscribers.each { |queue| queue << event } }
      end
    end
  end
end
