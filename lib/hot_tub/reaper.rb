module HotTub
  class Reaper < Thread

    # Creates a new Reaper thread for work.
    # Expects an object that responses to: :reap!
    # :shutdown and :reap_timeout
    # Threads swallow exceptions until they are joined,
    # so we rescue, log, and kill the reaper when an exception occurs
    # https://bugs.ruby-lang.org/issues/6647
    def self.spawn(obj)
      th = new {
        loop do
          begin
            obj.reap!
            break if obj.shutdown
            sleep(obj.reap_timeout || 600)
          rescue Exception => e
            HotTub.logger.error "HotTub::Reaper for #{obj.class.name} terminated with exception: #{e.message}"
            HotTub.logger.error e.backtrace.map {|line| " #{line}"}
            break
          end
        end
      }
      th[:name] = "HotTub::Reaper"
      th
    end

    # Mixin to dry up Reaper usage
    module Mixin
      attr_reader :reap_timeout, :reaper, :shutdown

      def reap!
        raise NoMethodError.new(':reap! must be redefined in your class')
      end
    end
  end
end
