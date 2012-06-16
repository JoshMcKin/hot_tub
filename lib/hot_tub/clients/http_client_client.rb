require "hot_tub"
require "hot_tub/clients/client"
require 'uri'
require 'http_client'
module HotTub
  
  class HttpClientClient < HotTub::Client 
  
    def initialize(options={})
      options[:default_host] = options[:url] if (options[:url] && options[:default_host].nil?)
      @options = options
      @client = HTTP::Client.new(options)
    end
    
    # pretty sure HttpClient handles this internally
    def sanitize_hot_tub_client
      @client
    end
    
    def close_hot_tub_client
      @client.shutdown
    end
    
    def dup
      self.class.new(@options)
    end  
  end
end

module HTTP
  class Client
    def read_response(request)
      r = execute(request)
      r.body
      r
    end
  end
end