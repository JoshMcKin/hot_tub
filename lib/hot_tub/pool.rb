module HotTub
  class Pool
    include HotTub::KnownClients
    attr_reader :current_size, :fetching_client, :last_activity
    
    # Thread-safe lazy connection pool
    #
    # == Example EM-Http-Request
    #     pool = HotTub::Pool.new { EM::HttpRequest.new("http://somewebservice.com") }
    #     pool.run {|clnt| clnt.get(:keepalive => true).body }
    #
    # HotTub::Pool defaults never_block to true, which means if we run out of
    # connections simply create a new client to continue operations.
    # The pool will grow and extra connections will be resued until activity dies down. 
    # If you would like to block and possibly throw an exception rather than temporarily 
    # grow the set :size, set :never_block to false; blocking_timeout defaults to 10 seconds.
    #
    # == Example without #never_block (will BlockingTimeout exception)
    #     pool = HotTub::Pool.new(:size => 1, :never_block => false, :blocking_timeout => 0.5) { EM::HttpRequest.new("http://somewebservice.com") }
    #
    #     begin
    #       pool.run {|clnt| clnt.get(:keepalive => true).body }
    #     rescue HotTub::BlockingTimeout => e
    #       puts "Our pool ran out: {e}"
    #     end
    #
    def initialize(options={},&client_block)
      raise ArgumentError, 'a block that initializes a new client is required' unless block_given?
      at_exit { close_all } # close connections at exit
      @client_block = client_block
      @options = {
        :size => 5,
        :never_block => true,     # Return new client if we run out
        :blocking_timeout => 10,  # in seconds
        :close => nil,            # => lambda {|clnt| clnt.close}
        :clean => nil             # => lambda {|clnt| clnt.clean}
      }.merge(options)
      @pool = []
      @current_size = 0
      @mutex = (HotTub.em? ? EM::Synchrony::Thread::Mutex.new : Mutex.new)
      @last_activity = Time.now
      @fetching_client = false
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
    def close_all
      @mutex.synchronize do
        while clnt = @pool.pop
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
      clnt = nil
      alarm = (Time.now + @options[:blocking_timeout])
      # block until we get an available client or raise Timeout::Error
      while clnt.nil?
        raise_alarm if alarm <= Time.now
        clnt = pop
      end
      clean_client(clnt)
      clnt
    end

    def raise_alarm
      message = "Could not fetch a free client in time. Consider increasing your pool size."
      HotTub.logger.error message
      raise BlockingTimeout, message
    end

    # Safely add client back to pool
    def push(clnt)
      @mutex.synchronize do
        @pool << clnt
      end
      nil # make sure never return the pool
    end

    # Safely pull client from pool, adding if allowed
    def pop
      @fetching_client = true # kill reap_pool
      @mutex.synchronize do
        add if add?
        clnt = @pool.pop # get warm connection
        if (clnt.nil? && @options[:never_block])
          add
          clnt = @pool.pop
        end
        @fetching_client = false
        clnt
      end
    ensure 
      reap_pool if reap_pool?
    end

    # create a new client from base client
    def new_client
      @client_block.call
    end

    # Only want to add a client if the pool is empty in keeping with
    # a lazy model.
    def add?
      (@pool.length == 0 && (@options[:size] > @current_size))
    end

    def add
      HotTub.logger.info "Adding HotTub client: #{@client.class.name} to pool"
      @last_activity = Time.now
      @current_size += 1
      @pool << new_client
    end

    def reap_pool?
      (!@fetching_client && (@current_size > @options[:size]) && ((@last_activity + (600)) < Time.now))
    end

    # Remove extra connections from front of pool
    def reap_pool
      @mutex.synchronize do
        if reap_pool? && clnt = @pool.shift
          @current_size -= 1
          close_client(clnt)
        end
      end
    end
  end
  class BlockingTimeout < StandardError;end
end
