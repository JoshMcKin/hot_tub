require "hot_tub"
require 'thread'
module HotTub
  # Super class for all HotTub clients
  # provides the 4 required methods to ensure compatibility
  class Client
    
    def client
      @client
    end
    
    def method_missing(method, *args, &blk)
      @client.send(method,*args,&blk)
    end
    
    # Override this method to perform the necessary action for ensure a client
    # is clean for use.
    def clean
      @client
    end
    
    def close
      @client
    end
    
    def dup
      self.class.new(@url,@options)
    end
    
    class << self
      def mutex
        Mutex.new
      end
    end
  end
end

