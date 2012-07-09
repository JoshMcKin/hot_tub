module HotTub
  class Session
   
    # OPTIONS
    # * :size - number of clients/connections for each pool
    # * :inactivity_timeout - number of seconds to wait before disconnecting, setting to 0 means the connection will not be closed
    # * :pool_timeout - the amount of seconds to block waiting for an available client, 
    # because this is blocking it should be an extremely short amount of 
    # time default to 0.5 seconds, if you need more consider enlarging your pool
    # instead of raising this number
    # :never_block - if set to true, a client will always be returned, 
    # but the pool size will never grow past that :size option, extra clients are closed
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
    
    # The synchronized pool for all our clients.
    #
    def pool(client=nil)
      @mutex.synchronize do
        if client
          return_client(client)
        else   
          add_client if add_client?
       end
        @pool
      end
    end
    
    # Run the block on the retrieved client. Good for ensure the same client
    # is used for multiple requests. For HTTP requests make sure you request has
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
      pool(client) if client
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
      pool(client) if client
    end
    
    private
    
    def add_client?
      (@pool.empty? && (@pool_data[:current_size] < @options[:size]))
    end
             
    def new_client
      @client.dup
    end 
        
    def add_client
      HotTub.logger.info "Adding HotTub client: #{@client.class.name} to pool"
      @pool_data[:current_size] += 1
      @pool << new_client         
      @pool
    end
    
    # return a client to the pool
    def return_client(client)
      if @pool.length < @options[:size]
        @pool << client
      else
        HotTub.logger.info "Closed extra client for #{@client.class.name}."
        client.close # Too hot in the hot tub...
      end
    end
    
    # Fetches an available client from the pool.
    # Hot tubs are not always clean... Make sure we have a good client. The client
    # should respond to clean, which checks to make sure the client is still 
    # viable, and reset if necessary.
    def fetch        
      client = nil
      alarm = (Time.now + @options[:blocking_timeout])       
      # block until we get an available client or raise Timeout::Error     
      while client.nil?
        raise_alarm if alarm <= Time.now
        client = pool.shift
        if client.nil? && (@options[:never_block])
          HotTub.logger.info "Adding never_block client for #{@client.class.name}."
          client = new_client
          client.mark_temporary
        end
      end
      client.clean
      client
    end
 
    def raise_alarm
      message = "Could not fetch a free client in time. Consider increasing your pool size for #{@client.class.name}."
      HotTub.logger.error message
      raise Timeout::Error, message    
    end
  end
end