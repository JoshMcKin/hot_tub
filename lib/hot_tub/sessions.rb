require 'uri'
module HotTub
  class Sessions
    include HotTub::KnownClients
    # HotTub::Session is a ThreadSafe::Cache where URLs are mapped to clients or pools. 
    # Excon clients are initialized to a specific domain, so we sometimes need a way to
    # manage multiple pools like when a process need to connect to various AWS resources. You can use any client
    # you choose, but make sure you client is thread safe.
    # Example:
    #
    #   sessions = HotTub::Sessions.new { |url| Excon.new(url) }
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
    #   sessions = HotTub::Sessions.new(:with_pool => true, :size => 12) {
    #       uri = URI.parse("http://somewebservice.com")
    #       http = Net::HTTP.new(uri.host, uri.port)
    #       http.use_ssl = false
    #       http.start
    #       http
    #     }
    #
    #   sessions.run("http://wwww.yahoo.com") do |conn|
    #     p conn.head('/').code
    #   end
    #
    #   sessions.run("https://wwww.google.com") do |conn|
    #     p conn.head('/').code
    #   end
    #
    def initialize(opts={},&new_client)
      raise ArgumentError, "HotTub::Sessions require a block on initialization that accepts a single argument" unless block_given?
      @options          = opts                    # To pass to pool
      @with_pool        = opts[:with_pool]        # Set to true to use HotTub::Pool with supplied new_client block
      @close_client     = opts[:close]            # => lambda {|clnt| clnt.close}
      @clean_client     = opts[:clean]            # => lambda {|clnt| clnt.clean}
      @reap_client      = opts[:reap]             # => lambda {|clnt| clnt.reap?} # should return boolean
      @new_client       = new_client              # => { |url| MyClient.new(url) } # block that accepts a url param
      @sessions         = ThreadSafe::Cache.new
      at_exit {drain!}
    end

    # Synchronizes initialization of our sessions
    # expects a url string or URI
    def sessions(url)
      key = to_key(url)
      return @sessions[key] if @sessions[key]
      if @with_pool
        @sessions[key] = HotTub::Pool.new(@options) { @new_client.call(url) }
      else
        @sessions[key] = @new_client.call(url) if @sessions[key].nil?
      end
      @sessions[key]
    end

    def run(url,&block)
      session = sessions(url)
      return session.run(&block) if session.is_a?(HotTub::Pool)
      block.call(sessions(url))
    end

    def clean
      @sessions.each_pair do |key,clnt|
        if clnt.is_a?(HotTub::Pool)
          clnt.clean
        else
          clean_client(clnt)
        end
      end
    end

    def drain!
      @sessions.each_pair do |key,clnt|
        if clnt.is_a?(HotTub::Pool)
          clnt.drain!
        else
          close_client(clnt)
        end
        @sessions[key] = nil
      end
    end

    def shutdown!
      @sessions.each_pair do |key,clnt|
        if clnt.is_a?(HotTub::Pool)
          clnt.shutdown!
        else
          close_client(clnt)
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
  Session = Sessions # alias for backwards compatibility
end
