require 'httpclient'
module HotTub
  class Pool
    attr_reader :current_size
    KNOWN_CLIENTS = {
      "HTTPClient" => {
        :close => lambda { |clnt|
          sessions = clnt.instance_variable_get(:@session_manager)
          sessions.reset_all if sessions
        }
      },
      'EventMachine::HttpConnection' => {
        :close => lambda { |clnt|
          if clnt.conn
            clnt.conn.close_connection
            clnt.instance_variable_set(:@deferred, true)
          end
        },
        :clean => lambda { |clnt|
          if clnt.conn && clnt.conn.error?
            HotTub.logger.info "Sanitizing connection : #{EventMachine::report_connection_error_status(@connection.conn.instance_variable_get(:@signature))}"
            clnt.conn.close_connection
            clnt.instance_variable_set(:@deferred, true)
          end
          clnt
        }
      }
    }

    # Generic lazy connection pool of HTTP clients
    # The default client is HTTPClient.
    # Clients must respond to :clean, :close, and :run
    #
    # == Example (HTTPClient)
    #     pool = HotTub::Pool.new(:size => 25)
    #     pool.run {|clnt| clnt.get('http://test.com').body }
    #
    # == Example with different client
    #     pool = HotTub::Pool.new { EM::HttpRequest.new("http://somewebservice.com") }
    #     pool.run {|clnt| clnt.get(:keepalive => true).body }
    #
    # HotTub::Pool defaults never_block to true, which means if run out of
    # connections simply create a new client to continue operations.
    # The pool size will remain consistent and extra connections will be closed
    # as they are pushed back. If you would like to throw an exception rather than
    # add new connections set :never_block to false; blocking_timeout defaults to 10 seconds.
    #
    # == Example without #never_block (will BlockingTimeout exception)
    #     pool = HotTub::Pool.new(:size => 1, :never_block => false, :blocking_timeout => 0.5)
    #
    #     begin
    #       pool.run {|clnt| clnt.get('http://test.com').body }
    #     rescue HotTub::BlockingTimeout => e
    #       puts "Our pool ran out: {e}"
    #     end
    #
    def initialize(options={},&client_block)
      @client_block = (block_given? ? client_block : lambda { HTTPClient.new })
      @options = {
        :size => 5,
        :never_block => true,
        :blocking_timeout => 10,
        :close => nil,
        :clean => nil
      }.merge(options)
      @pool = []
      @current_size = 0
      @clients = []
      @mutex = (HotTub.em? ? EM::Synchrony::Thread::Mutex.new : Mutex.new)
      @blocking_timeout = @options[:blocking_timeout]
      @never_block = @options[:never_block]
      @size = @options[:size]
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
        while clnt = @clients.pop
          begin
            close_client(clnt)
          rescue => e
            HotTub.logger.error "There was an error close one of your HotTub::Pool connections: #{e}"
          end
          @pool.delete(clnt)
        end
        @current_size = 0
      end
    end

    private

    # Returns an instance of the client for this pool.
    def client
      clnt = nil
      alarm = (Time.now + @blocking_timeout)
      # block until we get an available client or raise Timeout::Error
      while clnt.nil?
        raise_alarm if alarm <= Time.now
        clnt = pop
      end
      clean_client(clnt)
      clnt
    end

    # Attempts to clean the provided client, checking the options first for a clean block
    # then checking the known clients
    def clean_client(clnt)
      return @options[:clean].call(clnt) if @options[:clean] if @options[:clean].is_a?(Proc)
      if settings = KNOWN_CLIENTS[clnt.class.name]
        settings[:clean].call(clnt) if settings[:clean].is_a?(Proc)
      end
    end


    # Attempts to close the provided client, checking the options first for a close block
    # then checking the known clients
    def close_client(clnt)
      return @options[:close].call(clnt) if @options[:close] if @options[:close].is_a?(Proc)
      if settings = KNOWN_CLIENTS[clnt.class.name]
        settings[:close].call(clnt) if settings[:close].is_a?(Proc)
      end
    end

    def raise_alarm
      message = "Could not fetch a free client in time. Consider increasing your pool size for #{@client.class.name}."
      HotTub.logger.error message
      raise BlockingTimeout, message
    end

    # Safely add client back to pool
    def push(clnt)
      @mutex.synchronize do
        if @pool.length < @size
          @pool << clnt
        else
          @clients.delete(clnt)
          close_client(clnt)
        end
      end
      nil # make sure never return the pool
    end

    # Safely pull client from pool, adding if allowed
    def pop
      @mutex.synchronize do
        add if add?
        clnt = @pool.pop
        if (clnt.nil? && @never_block)
          HotTub.logger.info "Adding never_block client for #{@client.class.name}."
          clnt = new_client
        end
        clnt
      end
    end

    # create a new client from base client
    def new_client
      clnt = @client_block.call
      @clients << clnt
      clnt
    end

    # Only want to add a client if the pool is empty in keeping with
    # a lazy model.
    def add?
      (@pool.length == 0 && @current_size <= @size)
    end

    def add
      HotTub.logger.info "Adding HotTub client: #{@client.class.name} to pool"
      @current_size += 1
      @pool << new_client
    end
  end
  class BlockingTimeout < StandardError;end
end
