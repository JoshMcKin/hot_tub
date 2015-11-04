require 'uri'
module HotTub
  class Sessions
    include HotTub::KnownClients
    include HotTub::Reaper::Mixin
    attr_accessor :name

    # HotTub::Sessions simplifies managing multiple Pools in a single object
    # and using a single Reaper.
    #
    # == Example:
    #
    #   url  = "http://somewebservice.com"
    #   url2 = "http://somewebservice2.com"
    #
    #   sessions = HotTub::Sessions
    #   sessions.add(url,{:size => 12}) {
    #     uri = URI.parse(url)
    #     http = Net::HTTP.new(uri.host, uri.port)
    #     http.use_ssl = false
    #     http.start
    #     http
    #    }
    #   sessions.add(url2,{:size => 5}) {
    #     Excon.new(url2)
    #    }
    #
    #   sessions.run(url) do |conn|
    #     p conn.head('/').code
    #   end
    #
    #   sessions.run(url2) do |conn|
    #     p conn.head('/').code
    #   end
    #
    # === OPTIONS
    #   [:name]
    #     A string representing the name of your sessions used for logging.
    #
    #   [:reaper]
    #     If set to false prevents a HotTub::Reaper from initializing.
    #
    #   [:reap_timeout]
    #     Default is 600 seconds. An integer that represents the timeout for reaping the pool in seconds.
    #
    def initialize(opts={})
      @name             = (opts[:name] || self.class.name)
      @reaper           = opts[:reaper]
      @reap_timeout     = (opts[:reap_timeout] || 600)

      @_sessions        = {}
      @mutex            = Mutex.new
      @shutdown         = false

      at_exit {shutdown!}
    end

    # Adds a new HotTub::Pool for the given key unless
    # one already exists.
    def add(key, pool_options={}, &client_block)
      raise ArgumentError, 'a block that initializes a new client is required.' unless block_given?
      pool = nil
      return pool if pool = @_sessions[key]
      pool_options[:sessions] = true
      pool_options[:name] = "#{@name} - #{key}"
      @mutex.synchronize do
        @reaper ||= spawn_reaper if @reaper.nil?
        pool = @_sessions[key] ||= HotTub::Pool.new(pool_options, &client_block) unless @shutdown
      end
      pool
    end

    # Deletes and shutdowns the pool if its found.
    def delete(key)
      deleted = false
      pool = nil
      @mutex.synchronize do
        pool = @_sessions.delete(key)
      end
      if pool
        pool.reset!
        deleted = true
        HotTub.logger.info "[HotTub] #{key} was deleted from #{@name}." if HotTub.logger
      end
      deleted
    end

    def fetch(key)
      pool = @_sessions[key]
      raise MissingSession, "A session could not be found for #{key.inspect} #{@name}" unless pool
      pool
    end

    alias :[] :fetch

    def run(key, &run_block)
      pool = fetch(key)
      pool.run &run_block
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
