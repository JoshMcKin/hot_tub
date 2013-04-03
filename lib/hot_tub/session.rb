require 'uri'
module HotTub
  class Session

    # A HotTub::Session is a synchronized hash used to separate pools/clients by their domain.
    # Excon and EmHttpRequest clients are initialized to a specific domain, so we sometimes need a way to
    # manage multiple pools like when a process need to connect to various AWS resources.
    # Example:
    #
    #   sessions = HotTub::Session.new(:client_options => {:connect_timeout => 10}) { |url| Excon.new(url) }
    #
    #   sessions.run("http://wwww.yahoo.com") do |conn|
    #     p conn.head.response_header.status
    #   end
    #
    #   sessions.run("https://wwww.google.com") do |conn|
    #     p conn.head.response_header.status
    #   end
    #
    # Other client classes
    # If you have your own client class you can use sessions but your client class must initialize similar to
    # EmHttpRequest, accepting a URI and options see: hot_tub/clients/em_http_request_client.rb
    # Example Custom Client:
    #
    #   sessions = HotTub::Session.new({:never_block => false})  { |url| Excon.new(url) }
    #
    #   sessions.run("https://wwww.yahoo.com") do |conn|
    #     p conn.head.response_header.status # => create pool for "https://wwww.yahoo.com"
    #   end
    #
    #   sessions.run("https://wwww.google.com") do |conn|
    #     p conn.head.response_header.status # => create separate pool for "https://wwww.google.com"
    #   end
    def initialize(options={},&client_block)
      raise ArgumentError, "HotTub::Sessions requre a block on initialization that accepts a single argument" unless block_given?
      @options = {:with_pool => true}.merge(options)
      @client_block = client_block
      @sessions = Hash.new
      @mutex = (HotTub.em? ? EM::Synchrony::Thread::Mutex.new : Mutex.new)
    end

    # Synchronizes initialization of our sessions
    # expects a url string or URI
    def sessions(url)
      key = to_key(url)
      return @sessions[key] if @sessions[key]
      @mutex.synchronize do
        if @options[:with_pool]
          @sessions[key] ||= HotTub::Pool.new(@options) { @client_block.call(url) } 
        else
          @sessions[key] ||= @client_block.call(url)
        end
      end
    end

    def run(url,&block)
      session = sessions(url)
      return session.run(&block) if @options[:with_pool]
      block.call(sessions(url))
    end

    private

    def to_key(url)
      if url.is_a?(String)
        uri = URI(url)
      elsif url.is_a?(URI)
        uri = url
      else
        raise ArgumentError, "you must pass a string or a URI object"
      end
      "#{uri.scheme}-#{uri.host}"
    end
  end
end
