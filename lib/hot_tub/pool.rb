module HotTub
  class Pool
    include HotTub::KnownClients
    include HotTub::Reaper::Mixin

    attr_accessor :name

    # Thread-safe lazy connection pool
    #
    # == Example Net::HTTP
    #     pool = HotTub::Pool.new(:size => 10) {
    #       uri = URI.parse("http://somewebservice.com")
    #       http = Net::HTTP.new(uri.host, uri.port)
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
    #     pool.run { |clnt| s clnt.head('/').code }
    #
    #     begin
    #       pool.run { |clnt| s clnt.head('/').code }
    #     rescue HotTub::Pool::Timeout => e
    #       puts "Waited too long for a client: #{e}"
    #     end
    #
    #
    # === OPTIONS
    # [:name]
    #     A string representing the name of your pool used for logging.
    #
    # [:size]
    #   Default is 5. An integer that sets the size of the pool. Could be describe as minimum size the pool should
    #   grow to.
    #
    # [:max_size]
    #   Default is 0. An integer that represents the maximum number of connections allowed when :non_blocking is true.
    #   If set to 0, which is the default, there is no limit; connections will continue to open until load subsides
    #   long enough for reaping to occur.
    #
    # [:wait_timeout]
    #   Default is 10 seconds. An integer that represents the timeout when waiting for a client from the pool
    #   in seconds. After said time a HotTub::Pool::Timeout exception will be thrown
    #
    # [:close]
    #   Default is nil. Can be a symbol representing an method to call on a client to close the client or a lambda
    #   that accepts the client as a parameter that will close a client. The close option is performed on clients
    #   on reaping and shutdown after the client has been removed from the pool.  When nil, as is the default, no
    #   action is performed.
    #
    # [:clean]
    #   Default is nil. Can be a symbol representing an method to call on a client to clean the client or a lambda
    #   that accepts the client as a parameter that will clean a client. When nil, as is the default, no action is
    #   performed.
    #
    # [:reap?]
    #   Default is nil. Can be a symbol representing an method to call on a client that returns a boolean marking
    #   a client for reaping, or a lambda that accepts the client as a parameter that returns a boolean boolean
    #   marking a  client for reaping. When nil, as is the default, no action is performed.
    #
    # [:reaper]
    #   If set to false prevents, a HotTub::Reaper from initializing and all reaping will occur when the clients
    #   are returned to the pool, blocking the current thread.
    #
    # [:reap_timeout]
    #   Default is 600 seconds. An integer that represents the timeout for reaping the pool in seconds.
    #
    def initialize(opts={},&client_block)
      raise ArgumentError, 'a block that initializes a new client is required' unless block_given?
      @name             = (opts[:name] || self.class.name)
      @size             = (opts[:size] || 5)            # in seconds
      @wait_timeout     = (opts[:wait_timeout] || 10)   # in seconds
      @reap_timeout     = (opts[:reap_timeout] || 600)  # the interval to reap connections in seconds
      @max_size         = (opts[:max_size] || 0)        # maximum size of pool when non-blocking, 0 means no limit

      @close_client     = opts[:close]                  # => lambda {|clnt| clnt.close} or :close
      @clean_client     = opts[:clean]                  # => lambda {|clnt| clnt.clean} or :clean
      @reap_client      = opts[:reap?]                  # => lambda {|clnt| clnt.reap?} or :reap? # should return boolean
      @client_block     = client_block

      @_pool            = []    # stores available clients
      @_pool.taint
      @_out             = []    # stores all checked out clients
      @_out.taint

      @mutex            = Mutex.new
      @cond             = ConditionVariable.new

      @shutdown         = false

      @sessions_key     = opts[:sessions_key]
      @blocking_reap    = (opts[:reaper] == false && !@sessions_key)
      @reaper           = ((@sessions_key || (opts[:reaper] == false)) ? false : spawn_reaper)

      @never_block      = (@max_size == 0)

      at_exit {shutdown!} unless @sessions_key
    end

    # Preform an operations with a client/connection.
    # Requires a block that receives the client.
    def run
      clnt = pop
      yield clnt
    ensure
      push(clnt)
    end

    # Clean all clients currently checked into the pool.
    # Its possible clients may be returned to the pool after cleaning
    def clean!
      HotTub.logger.info "[HotTub] Cleaning pool #{@name}!" if HotTub.logger
      @mutex.synchronize do
        @_pool.each do |clnt|
          clean_client(clnt)
        end
      end
    end

    # Drain the pool of all clients currently checked into the pool.
    # After draining, wake all sleeping threads to allow repopulating the pool
    # or if shutdown allow threads to quickly finish their work
    # Its possible clients may be returned to the pool after cleaning
    def drain!
      HotTub.logger.info "[HotTub] Draining pool #{@name}!" if HotTub.logger
      @mutex.synchronize do
        begin
          while clnt = @_pool.pop
            close_client(clnt)
          end
        ensure
          @_out.clear
          @_pool.clear
          @cond.broadcast
        end
      end
    end
    alias :close! :drain!

    # Reset the pool.
    # or if shutdown allow threads to quickly finish their work
    # Clients from the previous pool will not return to pool.
    def reset!
      HotTub.logger.info "[HotTub] Resetting pool #{@name}!" if HotTub.logger
      @mutex.synchronize do
        begin
          while clnt = @_pool.pop
            close_client(clnt)
          end
        ensure
          @_out.clear
          @_pool.clear
          @cond.broadcast
        end
      end
      nil
    end

    # Kills the reaper and drains the pool.
    def shutdown!
      HotTub.logger.info "[HotTub] Shutting down pool #{@name}!" if HotTub.logger
      @shutdown = true
      kill_reaper if @reaper
      @mutex.synchronize do
        begin
          while clnt = @_pool.pop
            close_client(clnt)
          end
        ensure
          @_out.clear
          @_pool.clear
          @cond.broadcast
        end
      end
      nil
    end

    # Remove and close extra clients
    # Releases mutex each iteration because
    # reaping is a low priority action
    def reap!
      HotTub.logger.info "[HotTub] Reaping pool #{@name}!" if HotTub.log_trace?
      reaped = nil
      while !@shutdown
        @mutex.synchronize do
          if _reap?
            reaped = @_pool.shift
          else
            reaped = nil
          end
        end
        if reaped
          close_client(reaped)
        else
          break
        end
      end
    end

    def current_size
      @mutex.synchronize do
        _total_current_size
      end
    end

    # We must reset our @never_block cache
    # when we set max_size after initialization
    def max_size=max_size
      @never_block = (max_size == 0)
      @max_size = max_size
    end

    private

    ALARM_MESSAGE = "Could not fetch a free client in time. Consider increasing your pool size.".freeze

    def raise_alarm
      message = ALARM_MESSAGE
      HotTub.logger.error message if HotTub.logger
      raise Timeout, message
    end

    def close_orphan(clnt)
      HotTub.logger.info "[HotTub] An orphaned client attempted to return to #{@name}." if HotTub.log_trace?
      close_client(clnt)
    end

    # Safely add client back to pool, only if
    # that client is registered
    def push(clnt)
      if clnt
        orphaned = false
        @mutex.synchronize do
          begin
            if !@shutdown && @_out.delete(clnt)
              @_pool << clnt
            else
              orphaned = true
            end
          ensure
            @cond.signal
          end
        end
        close_orphan(clnt) if orphaned
        reap! if @blocking_reap
      end
      nil
    end

    # Safely pull client from pool, adding if allowed
    def pop
      alarm = (Time.now + @wait_timeout)
      clnt = nil
      dirty = false
      while !@shutdown
        raise_alarm if (Time.now > alarm)
        @mutex.synchronize do
          if clnt = @_pool.pop
            dirty = true
            @_out << clnt
          elsif clnt = _fetch_new(&@client_block)
            @_out << clnt
          else
            @cond.wait(@mutex,@wait_timeout)
          end
        end
        break if clnt
      end
      clean_client(clnt) if dirty && clnt
      clnt
    end

    ### START VOLATILE METHODS ###

    # Returns the total number of clients in the pool
    # and checked out. _total_current_size is volatile and
    # may be inaccurate if called outside @mutex.synchronize {}
    def _total_current_size
      (@_pool.length + @_out.length)
    end

    # Returns a new client if its allowed.
    # _add is volatile; and may cause threading issues
    # if called outside @mutex.synchronize {}
    def _fetch_new(&client_block)
      if (@never_block || (_total_current_size < @max_size))
        if client_block.arity == 0
          nc = yield
        else
          nc = yield @sessions_key
        end
        HotTub.logger.info "[HotTub] Adding client: #{nc.class.name} to #{@name}." if HotTub.log_trace?
        nc
      end
    end

    # Returns true if we have clients in the pool, the pool
    # is not shutting down, and there is overflow or the first
    # client in the pool is ready for reaping. _reap_pool? is
    # volatile; and may be inaccurate if called outside
    # @mutex.synchronize {}
    def _reap?
      (!@shutdown && ((@_pool.length > @size) || reap_client?(@_pool[0])))
    end

    ### END VOLATILE METHODS ###
    Timeout = Class.new(Exception) # HotTub::Pool::Timeout
  end

end
