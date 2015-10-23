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
    # == Example Redis
    #     # We don't want too many connections so we set our :max_size Under load our pool
    #     # can grow to 30 connections. Once load dies down our pool can be reaped back down to 5
    #     pool = HotTub::Pool.new(:size => 5, :max_size => 30, :reap_timeout => 60) { Redis.new }
    #     pool.set('hot', 'stuff')
    #     pool.get('hot')
    #     # => 'stuff'
    #
    # HotTub::Pool defaults never_block to true, which means if we run out of
    # clients simply create a new client to continue operations.
    # The pool will grow and extra clients will be reused until activity dies down.
    # If you would like to block and possibly throw an exception rather than temporarily
    # grow the set :size, set :never_block to false; wait_timeout defaults to 10 seconds.
    #
    # == Example with set pool size (will throw HotTub::Pool::Timeout exception)
    #     pool = HotTub::Pool.new(:size => 1, :max_size => 1, :wait_timeout => 0.5) {
    #       uri = URI.parse("http://someslowwebservice.com")
    #       http = Net::HTTP.new(uri.host, uri.port)
    #       http.use_ssl = false
    #       http.start
    #       http
    #     }
    #     pool.run { |clnt| puts clnt.head('/').code }
    #
    #     begin
    #       pool.run { |clnt| puts clnt.head('/').code }
    #     rescue HotTub::Pool::Timeout => e
    #       puts "Waited too long for a client: {e}"
    #     end
    #
    #
    # === OPTIONS
    #
    # [:size]
    #   Default is 5. An integer that sets the size of the pool. Could be describe as minimum size the pool should
    #   grow to.
    # [:max_size]
    #   Default is 0. An integer that represents the maximum number of connections allowed when :non_blocking is true.
    #   If set to 0, which is the default, there is no limit; connections will continue to open until load subsides
    #   long enough for reaping to occur.
    # [:wait_timeout]
    #   Default is 10 seconds. An integer that represents the timeout when waiting for a client from the pool
    #   in seconds. After said time a HotTub::Pool::Timeout exception will be thrown
    # [:reap_timeout]
    #   Default is 600 seconds. An integer that represents the timeout for reaping the pool in seconds.
    # [:close]
    #   Default is nil. Can be a symbol representing an method to call on a client to close the client or a lambda
    #   that accepts the client as a parameter that will close a client. The close option is performed on clients
    #   on reaping and shutdown after the client has been removed from the pool.  When nil, as is the default, no
    #   action is performed.
    # [:clean]
    #   Default is nil. Can be a symbol representing an method to call on a client to clean the client or a lambda
    #   that accepts the client as a parameter that will clean a client. When nil, as is the default, no action is
    #   performed.
    # [:reap]
    #   Default is nil. Can be a symbol representing an method to call on a client that returns a boolean marking
    #   a client for reaping, or a lambda that accepts the client as a parameter that returns a boolean boolean
    #   marking a  client for reaping. When nil, as is the default, no action is performed.
    # [:no_reaper]
    #   Default is nil. A boolean like value that if true prevents the reaper from initializing
    #
    def initialize(opts={},&new_client)
      raise ArgumentError, 'a block that initializes a new client is required' unless block_given?

      @size             = (opts[:size] || 5)                # in seconds
      @wait_timeout     = (opts[:wait_timeout] || 10)       # in seconds
      @reap_timeout     = (opts[:reap_timeout] || 600)      # the interval to reap connections in seconds
      @max_size         = (opts[:max_size] || 0)            # maximum size of pool when non-blocking, 0 means no limit

      @close_client     = opts[:close]                    # => lambda {|clnt| clnt.close} or :close
      @clean_client     = opts[:clean]                    # => lambda {|clnt| clnt.clean} or :clean
      @reap_client      = opts[:reap]                     # => lambda {|clnt| clnt.reap?} or :reap? # should return boolean
      @new_client       = new_client

      @pool             = []    # stores available clients
      @pool.taint
      @out              = []    # stores all checked out clients
      @out.taint

      @mutex            = Mutex.new
      @cond             = ConditionVariable.new

      @shutdown         = false                 # Kills reaper when true
      @reaper           = Reaper.spawn(self) unless opts[:no_reaper]

      at_exit {shutdown!}
    end

    # Hand off to client.run
    def run
      if block_given?
        clnt = client
        return yield clnt if clnt
      else
        raise ArgumentError, 'Run requires a block.'
      end
    ensure
      push(clnt) if clnt
    end

    # Clean all clients currently checked into the pool.
    # Its possible clients may be returned to the pool after cleaning
    def clean!
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
      @mutex.synchronize do
        begin
          while clnt = (@pool.pop || @out.pop)
            close_client(clnt)
          end
        ensure
          @cond.broadcast
        end
      end
    end
    alias :close! :drain!

    # Reset the pool and re-spawn reaper.
    # or if shutdown allow threads to quickly finish their work
    # Clients from the previous pool will not return to pool.
    def reset!
      @mutex.synchronize do
        begin
          while clnt = (@pool.pop || @out.pop)
            close_client(clnt)
          end
          if @reaper
            kill_reaper
            @reaper = Reaper.spawn(self)
          end
        ensure
          @cond.broadcast
        end
      end
      nil
    end

    # Kills the reaper and drains the pool.
    def shutdown!
      @shutdown = true
      kill_reaper if @reaper
    ensure
      drain!
    end

    # Remove and close extra clients
    # Releases mutex each iteration because
    # reaping is a low priority action
    def reap!
      loop do
        break if @shutdown
        reaped = nil
        @mutex.synchronize do
          reaped = @pool.shift if _reap?
        end
        if reaped
          close_client(reaped)
        else
          break
        end
      end
    end

    def never_block?
      (@max_size == 0)
    end

    def current_size
      @mutex.synchronize do
        _total_current_size
      end
    end

    private

    # Returns an instance of the client for this pool.
    def client
      clnt = pop
      clean_client(clnt) if clnt
      clnt
    end

    def alarm_time
      (Time.now + @wait_timeout)
    end

    def raise_alarm?(time)
      (time <= Time.now)
    end

    ALARM_MESSAGE = "Could not fetch a free client in time. Consider increasing your pool size."

    def raise_alarm
      message = ALARM_MESSAGE
      HotTub.logger.error message if HotTub.logger
      raise Timeout, message
    end

    # Safely add client back to pool, only if
    # that clnt is registered
    def push(clnt)
      if clnt
        @mutex.synchronize do
          begin
            if @out.delete(clnt)
              unless @shutdown
                @pool << clnt
              end
            end
          ensure
            @cond.signal
          end
        end
        close_client(clnt) if @shutdown
        reap! unless @reaper
      end
      nil
    end

    # Safely pull client from pool, adding if allowed
    def pop
      clnt = nil
      alarm = alarm_time
      while clnt.nil?
        break if @shutdown
        raise_alarm if raise_alarm?(alarm)
        @mutex.synchronize do
          if clnt = (@pool.pop || _fetch_new)
            @out << clnt
          else
            @cond.wait(@mutex,@wait_timeout)
          end
        end
      end
      clnt
    end

    ### START VOLATILE METHODS ###

    # Returns the total number of clients in the pool
    # and checked out. _total_current_size is volatile and
    # may be inaccurate if called outside @mutex.synchronize {}
    def _total_current_size
      (@pool.length + @out.length)
    end

    # Return true if we have reached our limit set by the :size option
    # _less_than_size? is volatile; and may be inaccurate
    # if called outside @mutex.synchronize {}
    def _less_than_size?
      (_total_current_size < @size)
    end

    # Return true if we have reached our limit set by the :max_size option
    # _less_than_max? is volatile; and may be inaccurate
    # if called outside @mutex.synchronize {}
    def _less_than_max?
      (_total_current_size < @max_size)
    end

    # Adds a new client to the pool if its allowed
    # _add is volatile; and may cause threading issues
    # if called outside @mutex.synchronize {}
    def _fetch_new
      return nil unless (@pool.empty? && (never_block? || _less_than_size?|| _less_than_max?))
      nc = @new_client.call
      HotTub.logger.info "Adding HotTub client: #{nc.class.name} to pool" if HotTub.logger
      nc
    end

    # Returns true if we have clients in the pool, the pool
    # is not shutting down, and there is overflow or the first
    # client in the pool is ready for reaping. _reap_pool? is
    # volatile; and may be inaccurate if called outside
    # @mutex.synchronize {}
    def _reap?
      ( !@pool.empty? && !@shutdown && ((@pool.length > @size) || reap_client?(@pool[0])))
    end

    ### END VOLATILE METHODS ###
    Timeout = Class.new(Exception) # HotTub::Pool::Timeout
  end

end
