require 'monitor'
module HotTub
  class Pool
    include HotTub::KnownClients
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
      @client_block     = client_block

      @pool             = []    # stores available clients
      @pool.taint
      @out              = []    # stores all checked out clients
      @out.taint

      @monitor          = Monitor.new
      @cond             = @monitor.new_cond
      @last_activity    = Time.now
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
      @monitor.synchronize do
        while (clnt = @pool.pop || clnt = @out.pop)
          begin
            close_client(clnt)
          rescue => e
            HotTub.logger.error "There was an error close one of your HotTub::Pool connections: #{e}"
          end
        end
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
      return false if clnt.nil?
      reap = false
      @monitor.synchronize do
        @out.delete(clnt)
        @pool << clnt
        reap = _reap_pool?
        @cond.signal
      end
      nil # make sure never return the pool
    ensure
      wake_reaper if reap
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
      clnt = nil
      alarm = alarm_time
      while clnt.nil?
        raise_alarm if raise_alarm?(alarm)
        @monitor.synchronize do
          @last_activity = Time.now
          if (@pool.empty?)
            if _add? || @never_block
              clnt = _add(true)
            else
              @cond.wait(@blocking_timeout)
            end
          else
            clnt = @pool.pop
          end
          @out << clnt if clnt
        end
      end
      clnt
    end

    def _current_size
      (@pool.length + @out.length)
    end

    # Only want to add a client if the pool is empty in keeping with
    # a lazy model. _add? is volatile; and may cause be in accurate
    # if called outside @pool_mutex.synchronize {}
    def _add?
      (@pool.empty? && (@size > _current_size))
    end

    # _add is volatile; and may cause threading issues
    # if called outside @pool_mutex.synchronize {}
    def _add(out=false)
      nc = @client_block.call
      HotTub.logger.info "Adding HotTub client: #{nc.class.name} to pool"
      if out
        @out << nc
        return nc
      else
        @pool << nc
      end
      nil
    end

    # _reap_pool? is volatile; and may cause be inaccurate
    # if called outside @pool_mutex.synchronize {}
    def _reap_pool?
      (!@pool.empty? && (_current_size > @size) && ((@last_activity + (600)) < Time.now))
    end

    # Remove extra connections from front of pool
    def reap_pool
      reaped = []
      loop do
        @monitor.synchronize do
          while _reap_pool?
            reaped << @pool.shift
          end
        end
        while clnt = reaped.pop
          close_client(clnt)
        end
        @monitor.sleep
      end
    end

    def wake_reaper
      begin
        @reaper.wakeup
      rescue ThreadError
      end
    end
  end

  class BlockingTimeout < StandardError;end
end
