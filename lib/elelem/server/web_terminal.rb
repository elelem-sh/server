# frozen_string_literal: true

module Elelem
  class Server
    class WebTerminal
      # Prompt ids are unique across every tab's terminal, so a page never
      # mistakes a new prompt for one it already answered.
      @next_id = 0
      @ids = Mutex.new

      def self.next_prompt_id
        @ids.synchronize { @next_id += 1 }
      end

      attr_reader :last_seen

      def initialize
        @subscribers = []
        @mutex = Mutex.new
        @prompts = {}
        @open = {}
        @last_seen = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # A page that subscribes again, after a reload, gets the prompts still
      # waiting for an answer, so the turn does not hang on one it cannot see.
      def subscribe
        Queue.new.tap do |queue|
          @mutex.synchronize do
            @subscribers << queue
            @open.each_value { |event| queue << event }
          end
        end
      end

      def subscribers
        @mutex.synchronize { @subscribers.size }
      end

      def unsubscribe(queue)
        @mutex.synchronize do
          @subscribers.delete(queue)
          @last_seen = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

      def interactive?
        true
      end

      def ask(prompt)
        queue = Queue.new
        event = @mutex.synchronize do
          id = self.class.next_prompt_id
          @prompts[id] = queue
          @open[id] = { type: "prompt", text: plain(prompt), id: id }
        end
        broadcast(event)
        queue.pop
      end

      def thinking(text)
        emit("thinking", text)
      end

      def say(text, as: nil)
        text = "\n  ✗ #{text}" if as == :error
        emit("content", text)
      end

      def doing(name, args, state: "+")
        say "#{state} #{name}(#{args})"
      end

      def waiting; end

      def print(text)
        emit("content", text)
      end

      def display_file(path, fallback: nil)
        content = File.read(path)
        raise ArgumentError unless content.valid_encoding?

        say(content)
      rescue Errno::ENOENT, Errno::EISDIR, ArgumentError
        say(fallback || path)
      end

      def answer(id, text)
        @mutex.synchronize do
          if @prompts.key?(id)
            @prompts[id] << text
            @prompts.delete(id)
            @open.delete(id)
          end
        end
      end

      def done
        broadcast(type: "done")
      end

      private

      def emit(type, text)
        plain = plain(text)
        return if plain.strip.empty?

        broadcast({ type: type, text: plain })
      end

      def plain(text)
        text.to_s.gsub(/\e\[[0-9;]*[a-zA-Z]/, "")
      end

      def broadcast(event)
        @mutex.synchronize { @subscribers.each { |queue| queue << event } }
      end
    end
  end
end
