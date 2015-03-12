require 'uri'
module HotTub
  class Sessions
    include HotTub::KnownClients
    include HotTub::Reaper::Mixin

    # HotTub::Session is a ThreadSafe::Cache where URLs are mapped to clients or pools.
    #
    #
    # == Example with Pool:
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
    # == Excon clients are initialized to a specific domain. Its sometimes useful
    # to have the options of initializing Excon connections after startup, in
    # a thread safe manner for multiple urls with a single object.
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
    #
    # === OPTIONS
    # [:with_pool]
    #   Default is false. A boolean that if true, wraps the new_client block in HotTub::Pool.new. All options
    #   are passed to the new HotTub::Pool object. See HotTub::Pool for options
    # [:close]
    #   Default is nil. Can be a symbol representing an method to call on a client to close the client or a lambda
    #   that accepts the client as a parameter that will close a client. The close option is performed on clients
    #   on reaping and shutdown after the client has been removed from the pool.  When nil, as is the default, no
    #   action is performed.
    # [:clean]
    #   Default is nil. Can be a symbol representing an method to call on a client to clean the client or a lambda
    #   that accepts the client as a parameter that will clean a client. When nil, as is the default, no action is
    #   performed.
    # [:reap]
    #   Default is nil. Can be a symbol representing an method to call on a client that returns a boolean marking
    #   a client for reaping, or a lambda that accepts the client as a parameter that returns a boolean boolean
    #   marking a  client for reaping. When nil, as is the default, no action is performed.
    # [:no_reaper]
    #   Default is nil. A boolean like value that if true prevents the reaper from initializing
    #
    def initialize(opts={},&new_client)
      raise ArgumentError, "HotTub::Sessions require a block on initialization that accepts a single argument" unless block_given?
      @with_pool        = opts[:with_pool]        # Set to true to use HotTub::Pool with supplied new_client block
      @close_client     = opts[:close]            # => lambda {|clnt| clnt.close}
      @clean_client     = opts[:clean]            # => lambda {|clnt| clnt.clean}
      @reap_client      = opts[:reap]             # => lambda {|clnt| clnt.reap?}  # should return boolean
      @new_client       = new_client              # => { |url| MyClient.new(url) } # block that accepts a url param
      @sessions         = ThreadSafe::Cache.new
      @shutdown         = false
      @reap_timeout     = (opts[:reap_timeout] || 600)      # the interval to reap connections in seconds
      @reaper           = Reaper.spawn(self) unless opts[:no_reaper]
      @pool_options     = {:no_reaper => true}.merge(opts) if @with_pool
      at_exit {drain!}
    end

    # Safely initializes of sessions
    # expects a url string or URI
    def session(url)
      key = to_key(url)
      return @sessions.get(key) if @sessions.get(key)
      if @with_pool
        @sessions.compute_if_absent(key) {
          HotTub::Pool.new(@pool_options) { @new_client.call(url) }
        }
      else
        @sessions.compute_if_absent(key) {@new_client.call(url)}
      end
      @sessions.get(key)
    end
    alias :sessions :session

    def run(url,&block)
      session = sessions(url)
      return session.run(&block) if session.is_a?(HotTub::Pool)
      block.call(sessions(url))
    end

    def clean!
      @sessions.each_pair do |key,clnt|
        if clnt.is_a?(HotTub::Pool)
          clnt.clean!
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
      end
      @sessions.clear
    end

    def shutdown!
      begin
        kill_reaper
      ensure
        drain!
      end
    end

    # Remove and close extra clients
    def reap!
      @sessions.each_pair do |key,clnt|
        if clnt.is_a?(HotTub::Pool)
          clnt.reap!
        else
          close_client(clnt) if reap_client?(clnt)
        end
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
