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
    
    def temporary?
      @temporary == true
    end
    
    def mark_temporary
      @temporary = true
    end
    
    # Override this method to perform the necessary action for ensure a client
    # is clean for use.
    def sanitize_hot_tub_client
      @client
    end
    
    def close_hot_tub_client
      @client
    end
    
    class << self
      def mutex
        Mutex.new
      end
    end
  end
end

