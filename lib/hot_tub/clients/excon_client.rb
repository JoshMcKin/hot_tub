require "hot_tub"
require "hot_tub/clients/client"
require "excon"
module HotTub
  class ExconClient < HotTub::Client 
  
    def initialize(url,options={})
      @url = url
      #make sure we turn on keep-alive
      @options = {:headers => {"Connection" => "keep-alive"}}.merge(options)
      @client = Excon.new(url,options)
    end
    
    # pretty sure Excon handles this internally
    def sanitize_hot_tub_client
      @client
    end
    
    def close_hot_tub_client
      @client.socket.close
    end
    
    def dup
      self.class.new(@url,@options)
    end
  end
end