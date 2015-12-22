module HotTub
  class Reaper
    attr_reader :thread

    def self.spawn(obj)
      self.new(obj)
    end

    # Creates a new Reaper thread for work.
    # Expects an object that responses to: :reap!
    # :shutdown and :reap_timeout
    # Threads swallow exceptions until they are joined,
    # so we rescue, log, and kill the reaper when an exception occurs
    # https://bugs.ruby-lang.org/issues/6647
    def initialize(obj)
      @thread = Thread.new {
        loop do
          begin
            break if obj.shutdown
            obj.reap!
            sleep(obj.reap_timeout || 600)
          rescue Exception => e
            HotTub.logger.error "[HotTub] Reaper for #{obj.class.name} terminated with exception: #{e.message}" if HotTub.logger
            HotTub.logger.error e.backtrace.map {|line| " #{line}"} if HotTub.logger
            break
          end
        end
      }
      @thread[:name] = "HotTub::Reaper"
      @thread.abort_on_exception = true
      @thread
    end

    def status
      @thread.status
    end

    def wakeup
      @thread.wakeup
    end

    def shutdown
      @thread.kill
      @thread.join
    end

    def alive?
      @thread.alive?
    end

    # Mixin to dry up Reaper usage
    module Mixin
      attr_reader :reap_timeout, :shutdown, :reaper

      # Setting reaper kills the current reaper.
      # If the values is truthy a new HotTub::Reaper
      # is created.
      def reaper=reaper
        kill_reaper
        if reaper
          @reaper = HotTub::Reaper.new(self)
        else
          @reaper = false
        end
      end

      def reap!
        raise NoMethodError.new('#reap! must be redefined in your class')
      end

      def kill_reaper
        if @reaper
          @reaper.shutdown
          @reaper = nil if @shutdown
        end
      end

      def spawn_reaper
        Reaper.spawn(self)
      end
    end
  end
end
