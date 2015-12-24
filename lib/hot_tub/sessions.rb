require 'uri'
module HotTub
  class Sessions
    include HotTub::KnownClients
    include HotTub::Reaper::Mixin
    attr_accessor :name,
      :default_client

    # HotTub::Sessions simplifies managing multiple Pools in a single object
    # and using a single Reaper.
    #
    # == Example:
    #
    #   sessions = HotTub::Sessions(:size => 10) do |url|
    #     uri = URI.parse(url)
    #     http = Net::HTTP.new(uri.host, uri.port)
    #     http.start
    #     http
    #   end
    #
    #   # Every time we pass a url that lacks a entry in our
    #   # sessions, a new HotTub::Pool is added for that url
    #   # using the &default_client.
    #   #
    #   sessions.run("https://www.google.com"") do |conn|
    #     p conn.get('/').code
    #   end
    #
    #   sessions.run("https://www.yahoo.com"") do |conn|
    #     p conn.get('/').code
    #   end
    #
    #   # Lazy load a non-default connection
    #
    #   excon_url = "http://somewebservice2.com"
    #
    #   sessions.stage(excon_url,{:size => 5}) {
    #     Excon.new(excon_url, :thread_safe_socket => false)
    #    }
    #
    #   # Excon connection is created on the first call to `.run`
    #   sessions.run(excon_url) do |conn|
    #     p conn.head.code
    #   end
    #
    #
    #   # Add a connection, which returns a HotTub::Pool instance
    #
    #   excon_url2 = "http://somewebservice2.com"
    #
    #   MY_CON = sessions.add(excon_url2,{:size => 5}) {
    #     Excon.new(excon_url2, :thread_safe_socket => false)
    #    }
    #
    #   # Uses Excon
    #   MY_CON.run(excon_url) do |conn|
    #     p conn.head.code
    #   end
    #
    # === OPTIONS
    #
    #   &default_client
    #     An optional block for a default client for your pools. If your block accepts a
    #     parameters, they session key is passed to the block. Your default client
    #     block will be overridden if you pass a client block to get_or_set
    #
    #   [:pool_options]
    #     Default options for your HotTub::Pools. If you pass options to #get_or_set those options
    #     override :pool_options.
    #
    #   [:name]
    #     A string representing the name of your sessions used for logging.
    #
    #   [:reaper]
    #     If set to false prevents a HotTub::Reaper from initializing for these sessions.
    #
    #   [:reap_timeout]
    #     Default is 600 seconds. An integer that represents the timeout for reaping the pool in seconds.
    #
    def initialize(opts={}, &default_client)
      @name                 = (opts[:name] || self.class.name)
      @reaper               = opts[:reaper]
      @reap_timeout         = (opts[:reap_timeout] || 600)
      @default_client       = default_client
      @pool_options         = (opts[:pool_options] || {})

      @_staged              = {}
      @_staged.taint
      
      @_sessions            = {}
      @_sessions.taint

      @mutex                = Mutex.new
      @shutdown             = false

      at_exit {shutdown!}
    end

    # Sets arguments / settings for a session that will be 
    # lazy loaded, returns nil because pool is not created
    def stage(key, pool_options={}, &client_block)
      @mutex.synchronize do
        @_staged[key] = [pool_options,client_block]
      end
      nil
    end

    # Returns a HotTub::Pool for the given key. If a session
    # is not found and the is a default_client set, a session will
    # be created for the key using the default_client.
    def get(key)
      pool = @_sessions[key]
      unless pool
        @mutex.synchronize do
          unless @shutdown
            @reaper = spawn_reaper if @reaper.nil?
            unless pool = @_sessions[key]
              settings = @_staged[key]
              clnt_blk = (settings[1] || @default_client)
              op = @pool_options.merge(settings[0])
              op[:sessions_key] = key
              op[:name] = "#{@name} - #{key}"
              pool = @_sessions[key] = HotTub::Pool.new(op, &clnt_blk)
            end
          end
        end
      end
      pool
    end

    # Adds session unless it already exists and returns
    # the session
    def get_or_set(key, pool_options={}, &client_block)
      unless @_staged[key]
        @mutex.synchronize do
          @_staged[key] ||= [pool_options,client_block]
        end
      end
      get(key)
    end
    alias :add :get_or_set

    # Deletes and shutdowns the pool if its found.
    def delete(key)
      deleted = false
      pool = nil
      @mutex.synchronize do
        pool = @_sessions.delete(key)
      end
      if pool
        pool.shutdown!
        deleted = true
        HotTub.logger.info "[HotTub] #{key} was deleted from #{@name}." if HotTub.logger
      end
      deleted
    end

    def fetch(key)
      unless pool = get(key, &@default_client)
        raise MissingSession, "A session could not be found for #{key.inspect} #{@name}"
      end
      pool
    end

    alias :[] :fetch

    def run(key, &run_block)
      pool = fetch(key)
      pool.run(&run_block)
    end

    def clean!
      HotTub.logger.info "[HotTub] Cleaning #{@name}!" if HotTub.logger
      @mutex.synchronize do
        @_sessions.each_value do |pool|
          break if @shutdown
          pool.clean!
        end
      end
      nil
    end

    def drain!
      HotTub.logger.info "[HotTub] Draining #{@name}!" if HotTub.logger
      @mutex.synchronize do
        @_sessions.each_value do |pool|
          break if @shutdown
          pool.drain!
        end
      end
      nil
    end

    def reset!
      HotTub.logger.info "[HotTub] Resetting #{@name}!" if HotTub.logger
      @mutex.synchronize do
        @_sessions.each_value do |pool|
          break if @shutdown
          pool.reset!
        end
      end
      nil
    end

    def shutdown!
      @shutdown = true
      HotTub.logger.info "[HotTub] Shutting down #{@name}!" if HotTub.logger
      begin
        kill_reaper
      ensure
        @mutex.synchronize do
          @_sessions.each_value do |pool|
            pool.shutdown!
          end
        end
      end
      nil
    end

    # Remove and close extra clients
    def reap!
      HotTub.logger.info "[HotTub] Reaping #{@name}!" if HotTub.log_trace?
      @mutex.synchronize do
        @_sessions.each_value do |pool|
          break if @shutdown
          pool.reap!
        end
      end
      nil
    end

    MissingSession = Class.new(Exception)
  end
end
