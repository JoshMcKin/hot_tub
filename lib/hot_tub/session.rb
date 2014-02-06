require 'uri'
module HotTub

  class Session
    include HotTub::KnownClients
    # HotTub::Session is a ThreadSafe::Cache where URLs are mapped to clients or pools. 
    # Excon clients are initialized to a specific domain, so we sometimes need a way to
    # manage multiple pools like when a process need to connect to various AWS resources. You can use any client
    # you choose, but make sure you client is thread safe.
    # Example:
    #
    #   sessions = HotTub::Session.new { |url| Excon.new(url) }
    #
    #   sessions.run("http://wwww.yahoo.com") do |conn|
    #     p conn.head.status
    #   end
    #
    #   sessions.run("https://wwww.google.com") do |conn|
    #     p conn.head.status
    #   end
    #
    # Example with Pool:
    # You can initialize a HotTub::Pool with each client by passing :with_pool as true and any pool options
    #   sessions = HotTub::Session.new(:with_pool => true, :size => 12) { EM::HttpRequest.new("http://somewebservice.com") }
    #
    #   sessions.run("http://wwww.yahoo.com") do |conn|
    #     p conn.head.response_header.status
    #   end
    #
    #   sessions.run("https://wwww.google.com") do |conn|
    #     p conn.head.response_header.status
    #   end
    #
    def initialize(options={},&client_block)
      raise ArgumentError, "HotTub::Sessions require a block on initialization that accepts a single argument" unless block_given?
      @options = options || {}
      @client_block = client_block
      @sessions =  ThreadSafe::Cache.new
      at_exit {close_all}
    end

    # Synchronizes initialization of our sessions
    # expects a url string or URI
    def sessions(url)
      key = to_key(url)
      return @sessions[key] if @sessions[key]
      if @options[:with_pool]
        @sessions[key] = HotTub::Pool.new(@options) { @client_block.call(url) }
      else
        @sessions[key] = @client_block.call(url) if @sessions[key].nil?
      end
      @sessions[key]
    end

    def run(url,&block)
      session = sessions(url)
      return session.run(&block) if session.is_a?(HotTub::Pool)
      block.call(sessions(url))
    end

    # Calls close on all pools/clients in sessions
    def close_all
      @sessions.each_pair do |key,clnt|
        if clnt.is_a?(HotTub::Pool)
          clnt.close_all
        else
          begin
            close_client(clnt)
          rescue => e
            HotTub.logger.error "There was an error close one of your HotTub::Session clients: #{e}"
          end
        end
        @sessions[key] = nil
      end
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
      "#{uri.scheme}://#{uri.host}:#{uri.port}"
    end
  end
end
