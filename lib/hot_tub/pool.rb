module HotTub
  class Pool
    include HotTub::KnownClients
    attr_reader :current_size, :last_activity

    # Thread-safe lazy connection pool modeled after Queue
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
    # connections simply create a new client to continue operations.
    # The pool will grow and extra connections will be resued until activity dies down.
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
    def initialize(opts={},&client_block)
      raise ArgumentError, 'a block that initializes a new client is required' unless block_given?

      @size             = (opts[:size] || 5)              # in seconds
      @blocking_timeout = (opts[:blocking_timeout] || 10) # in seconds
      @close            = opts[:close]                    # => lambda {|clnt| clnt.close}
      @clean            = opts[:clean]                    # => lambda {|clnt| clnt.clean}
      @never_block      = (opts[:never_block].nil? ? true : opts[:never_block]) # Return new client if we run out
      @client_block = client_block

      @pool             = []    # stores available connection
      @pool.taint
      @register         = []    # stores all connections at all times
      @register.taint
      @waiting          = []    # waiting threads
      @waiting.taint
      @stale            = []    # stale/orphan connections to be reaped
      @stale.taint      
      @pool_mutex       = Mutex.new
      @current_size     = 0
      @last_activity    = Time.now
      @fetching_client  = false
      @reaper           = Thread.new {
        reap_pool
      }
      at_exit {close_all}
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

    # Calls close on all connections and reset the pools
    # Its possible clients may be returned to the pool after close_all,
    # but the close_client block ensures the client should be stale
    # and the clean method should repairs those connections if they are called
    def close_all
      @pool_mutex.synchronize do
        while clnt = @register.pop
          @pool.delete(clnt)
          begin
            close_client(clnt)
          rescue => e
            HotTub.logger.error "There was an error close one of your HotTub::Pool connections: #{e}"
          end
        end
        @current_size = 0
      end
    end

    private

    # Returns an instance of the client for this pool.
    def client
      clnt = pop
      clean_client(clnt)
      clnt
    end

    # Safely add client back to pool, only if
    # that clnt is registered
    def push(clnt)
      pushed = false
      reap = false
      @pool_mutex.synchronize do
        if @register.include?(clnt)
          pushed = true
          @register.delete(clnt)
          @register << clnt
          @pool << clnt
        end
        begin
          t = @waiting.shift
          t.wakeup if t
        rescue ThreadError
          retry
        end
        reap = _reap_pool?
      end
      @stale << clnt unless pushed # orphan close
      nil # make sure never return the pool
    ensure
      begin
        @reaper.wakeup if reap
      rescue ThreadError
      end
    end

    def alarm_time
      (Time.now + @blocking_timeout)
    end

    def raise_alarm?(alm_time)
      (alm_time <= Time.now)
    end

    def raise_alarm
      message = "Could not fetch a free client in time. Consider increasing your pool size."
      HotTub.logger.error message
      raise BlockingTimeout, message
    end

    # Safely pull client from pool, adding if allowed
    def pop
      @fetching_client = true # kill reap_pool
      clnt = nil
      @pool_mutex.synchronize do
        alarm = alarm_time
        while clnt.nil?
          raise_alarm if raise_alarm?(alarm)
          if (@pool.empty?)
            if _add? || @never_block
              clnt = _add(true)
            else
              @waiting.push Thread.current
              @pool_mutex.sleep(@blocking_timeout)
            end
          else
            clnt = @pool.pop
          end
        end
        @fetching_client = false
        clnt
      end
    end

    # _reap_pool? is volatile; and may cause be inaccurate
    # if called outside @pool_mutex.synchronize {}
    def _reap_pool?
      (!@fetching_client && (@current_size > @size) && ((@last_activity + (600)) < Time.now))
    end

    # Remove extra connections from front of pool
    def reap_pool
      @pool_mutex.synchronize do
        while true
          while stale = @stale.pop
            close_client(stale)
          end
          while _reap_pool? && clnt = @pool.shift
            @register.delete(clnt)
            @current_size -= 1
            close_client(clnt)
          end
          @pool_mutex.sleep
        end
      end
    end

    # Only want to add a client if the pool is empty in keeping with
    # a lazy model. _add? is volatile; and may cause be in accurate
    # if called outside @pool_mutex.synchronize {}
    def _add?
      (@pool.length == 0 && (@size > @current_size))
    end

    # _add is volatile; and may cause threading issues
    # if called outside @pool_mutex.synchronize {}
    def _add(no_pool=false)
      @last_activity = Time.now
      @current_size += 1
      nc = @client_block.call
      HotTub.logger.info "Adding HotTub client: #{nc.class.name} to pool"
      @register << nc
      return nc if no_pool
      @pool << nc
      nil
    end
  end

  class BlockingTimeout < StandardError;end
end
