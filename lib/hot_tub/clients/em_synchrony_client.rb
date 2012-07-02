require "hot_tub"
require "hot_tub/clients/client"
module HotTub
  class EmSynchronyClient < HotTub::Client 
  
    def initialize(url,options={})
      @url = url
      @options = {:inactivity_timeout => 0}.merge(options)     
      @client = EM::HttpRequest.new(url,options)
    end
    
    def clean   
      if @client.conn && @client.conn.error?
        HotTub.logger.info "Sanitizing connection : #{EventMachine::report_connection_error_status(@client.conn.instance_variable_get(:@signature))}"
        @client.conn.close_connection
        @client.instance_variable_set(:@deferred, true)
      end
      @client
    end
    
    def close
      @client.conn.close_connection if @client.conn
    end
    
    # Default keepalive true for HTTP requests
    [:get,:head,:delete,:put,:post].each do |m|
      define_method m do |options={},&blk|
        options ={} if options.nil?
        options[:keepalive] = true
        @client.send(m,options,&blk)
      end
    end
    
    class << self
      # Use a fiber safe mutex
      def mutex
        EM::Synchrony::Thread::Mutex.new
      end
    end
  end
end