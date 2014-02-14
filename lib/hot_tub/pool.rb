module HotTub
  class Pool
    include HotTub::KnownClients
    include HotTub::Reaper::Mixin
    attr_reader :current_size, :last_activity

    # Thread-safe lazy connection pool
    #
    # == Example Net::HTTP
    #     pool = HotTub::Pool.new(:size => 10) {
    #       uri = URI.parse("http://somewebservice.com")
    #       http = Net::HTTP.new(uri.host, uri.port)
    #       http.use_ssl = false
    #       http.start
    #       http
    #     }
    #     pool.run {|clnt| puts clnt.head('/').code }
    #
    # HotTub::Pool defaults never_block to true, which means if we run out of
    # clients simply create a new client to continue operations.
    # The pool will grow and extra clients will be reused until activity dies down.
    # If you would like to block and possibly throw an exception rather than temporarily
    # grow the set :size, set :never_block to false; blocking_timeout defaults to 10 seconds.
    #
    # == Example without #never_block (will BlockingTimeout exception)
    #     pool = HotTub::Pool.new(:size => 1, :never_block => false, :blocking_timeout => 0.5) {
    #       uri = URI.parse("http://somewebservice.com")
    #       http = Net::HTTP.new(uri.host, uri.port)
    #       http.use_ssl = false
    #       http.start
    #       http
    #     }
    #     pool.run { |clnt| puts clnt.head('/').code }
    #
    #     begin
    #       pool.run { |clnt| puts clnt.head('/').code }
    #     rescue HotTub::BlockingTimeout => e
    #       puts "Our pool ran out: {e}"
    #     end
    #
    def initialize(opts={},&new_client)
      raise ArgumentError, 'a block that initializes a new client is required' unless block_given?

      @size             = (opts[:size] || 5)                # in seconds
      @blocking_timeout = (opts[:blocking_timeout] || 10)   # in seconds
      @non_blocking     = (opts[:non_blocking].nil? ? true : opts[:non_blocking]) # Return new client if we run out
      @reap_timeout     = (opts[:reap_timeout] || 600)      # the interval to reap connections in seconds
      @close_out        = opts[:close_out]                  # if true on drain! call close_client block on checked out clients
      @max_size         = (opts[:max_size] || 0)            # maximum size of pool when non-blocking, 0 means no limit

      @close_client     = opts[:close]                    # => lambda {|clnt| clnt.close}
      @clean_client     = opts[:clean]                    # => lambda {|clnt| clnt.clean}
      @reap_client      = opts[:reap]                     # => lambda {|clnt| clnt.reap?} # should return boolean
      @new_client       = new_client

      @pool             = []    # stores available clients
      @pool.taint
      @out              = []    # stores all checked out clients
      @out.taint

      @mutex            = Mutex.new
      @cond             = ConditionVariable.new

      @shutdown         = false                 # Kills reaper when true
      @reaper           = Reaper.spawn(self) unless opts[:no_reaper]

      @last_activity    = Time.now              # Repear unlocks mutex when updated

      at_exit {shutdown!}
    end

    # Hand off to client.run
    def run(&block)
      clnt = client
      if block_given?
        return block.call(clnt) if clnt
      else
        raise ArgumentError, 'Run requires a block.'
      end
    ensure
      push(clnt) if clnt
    end

    # Clean all clients currently checked into the pool.
    # Its possible clients may be returned to the pool after cleaning
    def clean!
      update_last_activity
      @mutex.synchronize do
        @pool.each do |clnt|
          clean_client(clnt)
        end
      end
    end

    # Drain the pool of all clients currently checked into the pool.
    # After draining, wake all sleeping threads to allow repopulating the pool
    # or if shutdown allow threads to quickly finish their work
    # Its possible clients may be returned to the pool after cleaning
    def drain!
      update_last_activity
      @mutex.synchronize do
        while clnt = (@pool.pop || (@close_out && @out.pop))
          close_client(clnt)
        end
        @cond.broadcast
      end
    end
    alias :close! :drain!
    alias :close_all! :drain!

    # Kills the reaper and drains the pool.
    def shutdown!
      @shutdown = true
      drain!
    end

    # Remove and close extra clients
    def reap!
      reaped = []
      @mutex.synchronize do
        while _reap?
          reaped << @pool.shift
        end
      end
      while clnt = reaped.pop
        close_client(clnt)
      end
    end

    def never_block?
      (@non_blocking && (@max_size == 0))
    end

    private

    # Returns an instance of the client for this pool.
    def client
      clnt = pop
      clean_client(clnt) if clnt
      clnt
    end

    # Updating last activity causes the reaper
    # to unlock the monitor
    def update_last_activity
      @last_activity = Time.now
    end

    def alarm_time
      (Time.now + @blocking_timeout)
    end

    def raise_alarm?(time)
      (time <= Time.now)
    end

    def raise_alarm
      message = "Could not fetch a free client in time. Consider increasing your pool size."
      HotTub.logger.error message
      raise BlockingTimeout, message
    end

    # Safely add client back to pool, only if
    # that clnt is registered
    def push(clnt)
      if clnt
        update_last_activity
        @mutex.synchronize do
          @out.delete(clnt)
          if @shutdown
            close_client(clnt)
          else
            @pool << clnt
          end
          @cond.signal
        end
      end
      nil
    end

    # Safely pull client from pool, adding if allowed
    def pop
      clnt = nil
      alarm = alarm_time
      update_last_activity
      while clnt.nil?
        break if @shutdown
        raise_alarm if raise_alarm?(alarm)
        @mutex.synchronize do
          if (_space? || _add)
            @out << clnt = @pool.pop
          else
            @cond.wait(@mutex)
          end
        end
      end
      clnt
    end

    ### START VOLATILE METHODS ###

    # _empty? is volatile; and may cause be inaccurate
    # if called outside @monitor.synchronize {}
    def _empty?
      @pool.empty?
    end

    # _available? is volatile; and may cause be inaccurate
    # if called outside @monitor.synchronize {}
    def _space?
      !_empty?
    end

    def _total_count
      (@pool.length + @out.length)
    end

    def _less_than_size?
      (_total_count < @size)
    end

    def _less_than_max?
      (@non_blocking && (_total_count < @max_size))
    end

    # Only want to add a client if the pool is empty in keeping with
    # a lazy model. _add? is volatile; and may cause be in accurate
    # if called outside @monitor.synchronize {}
    def _add?
      (_empty? && (never_block? || _less_than_size?|| _less_than_max?))
    end

    # _add is volatile; and may cause threading issues
    # if called outside @monitor.synchronize {}
    def _add
      return false unless _add?
      nc = @new_client.call
      HotTub.logger.info "Adding HotTub client: #{nc.class.name} to pool"
      @pool << nc
      true
    end

    # _reap_pool? is volatile; and may cause be inaccurate
    # if called outside @monitor.synchronize {}
    def _reap?
      (_space? && !@shutdown && ( _overflow_expired? || reap_client?(@pool[0])))
    end

    def _overflow_expired?
      (_total_count > @size) && ((@last_activity + (@reap_timeout)) < Time.now)
    end

    ### END VOLATILE METHODS ###
  end

  class BlockingTimeout < StandardError;end
end
