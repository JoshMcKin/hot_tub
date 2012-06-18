module HotTub
  class Session
   
    # OPTIONS
    # * :size - number of connections for each pool
    # * :inactivity_timeout - number of seconds to wait before disconnecting, setting to 0 means the connection will not be closed
    # * :pool_timeout - the amount of seconds to block waiting for an availble connection, 
    # because this is blocking it should be an extremely short amount of 
    # time default to 0.5 seconds, if you need more consider enlarging your pool
    # instead of raising this number
    # :never_block - if set to true, a connection will always be returned, but 
    # these extra connections are not added to the pool when the request is completed
    def initialize(client,options={})     
      @options = {
        :size => 5,
        :never_block => false,
        :blocking_timeout => 0.5
      }.merge(options || {})
      @pool = []
      @pool_data = {:current_size => 0}   
      @client = client
      @mutex = (@client.respond_to?(:mutex) ? @client.mutex : Mutex.new)  
    end
            
    def pool
      @mutex.synchronize do
        add_client if add_client?
        @pool
      end
    end
  
    # Fetches an avaible client from the pool.
    # Hot tubs are not always clean... Make sure we have a good connection. The client
    # should respond to sanitize_hot_tub_connection, which checks to make sure
    # the connection is still viable, and resets if not
    def fetch        
      client = nil
      alarm = (Time.now + @options[:blocking_timeout])       
      # block until we get an available connection or Timeout::Error     
      while client.nil?
        raise_alarm if alarm <= Time.now

        client = pool.shift
        if client.nil? && (@options[:never_block])
          HotTub.logger.info "Adding never_block client for #{@client.class.name}, will not be returned to pool."
          client = new_client
          client.mark_temporary
        end
      end
      client.sanitize_hot_tub_client
      client
    end
  
    # return a client to the pool
    def return_client(client)
      if client.temporary?
        client.close_hot_tub_client # Too hot in the hot tub...
      else
        @pool << client 
      end
      @pool
    end
    
    # Run the block on the retrieved connection. Good for ensure the same client
    # is used for mulitple requests. For HTTP requests make sure you request has
    # keep-alive properly set for your client
    # EX:
    #   @pool = HotTub.new(HotTub::ExconClient.new("https://some_web_site.com"))
    #   results = []
    #   @pool.run do |client|
    #     results.push  (client.get(:query => {:foo => "bar"}))
    #     results.push  (client.get(:query => {:bar => "foo"})) # reuse client
    #   end
    #
    def run(&block)
      client = fetch     
      if block_given?
        block.call(client)
      else
        raise ArgumentError, 'Run requires a block.'
      end
    ensure
      return_client(client) if client
    end
   

    # Let pool instance respond to client methods. For HTTP request make sure you 
    # requests has keep-alive properly set for your client
    # EX: 
    #   @pool = HotTub.new(HotTub::ExconClient.new("https://some_web_site.com"))
    #   r1 = @pool.get(:query => {:foo => "bar"})
    #   r2 = @pool.get(:query => {:bar => "foo"}) # uses a different client
    #
    def method_missing(method, *args, &blk)
      client = fetch
      client.send(method,*args,&blk)
    ensure
      return_client(client) if client
    end
    
    private
    
    def add_client?
      (@pool.empty? && (@pool_data[:current_size] < @options[:size]))
    end
        
    def add_client
      HotTub.logger.info "Adding HotTub client: #{@client.class.name} to pool"
      @pool_data[:current_size] += 1
      @pool << new_client         
      @pool
    end
        
    def new_client
      @client.dup
    end  

    def raise_alarm
      message = "Could not fetch a free client in time. Consider increasing your pool size for #{@client.class.name}."
      HotTub.logger.error message
      raise Timeout::Error, message    
    end
  end
end