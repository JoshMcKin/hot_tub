require 'uri'
module HotTub
  class Session
    include HotTub::KnownClients
    # A HotTub::Session is a synchronized hash used to separate pools/clients by their domain.
    # Excon and EmHttpRequest clients are initialized to a specific domain, so we sometimes need a way to
    # manage multiple pools like when a process need to connect to various AWS resources. You can use any client
    # you choose, but make sure you client is threadsafe.
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
    #
    def initialize(options={},&client_block)
      raise ArgumentError, "HotTub::Sessions requre a block on initialization that accepts a single argument" unless block_given?
      @options = options || {}
      @client_block = client_block
      @sessions = Hash.new
      @mutex = (em_client? ? EM::Synchrony::Thread::Mutex.new : Mutex.new)
      HotTub.hot_at_exit( em_client? ) {close_all}
    end

    # Synchronizes initialization of our sessions
    # expects a url string or URI
    def sessions(url)
      key = to_key(url)
      return @sessions[key] if @sessions[key]
      @mutex.synchronize do
        if @options[:with_pool]
          @sessions[key] = HotTub::Pool.new(@options) { @client_block.call(url) }
        else
          @sessions[key] = @client_block.call(url) if @sessions[key].nil?
        end
        @sessions[key]
      end
    end

    def run(url,&block)
      session = sessions(url)
      return session.run(&block) if session.is_a?(HotTub::Pool)
      block.call(sessions(url))
    end

    # Calls close on all pools/clients in sessions
    def close_all
      @sessions.each do |key,clnt|
        if clnt.is_a?(HotTub::Pool)
          clnt.close_all
        else
          begin
            close_client(clnt)
          rescue => e
            HotTub.logger.error "There was an error close one of your HotTub::Session clients: #{e}"
          end
        end
        @mutex.synchronize do
          @sessions[key] = nil
        end
      end
    end

    private

    def em_client?
      begin
        (HotTub.em_synchrony? && @client_block.call("http://moc").is_a?(EventMachine::HttpConnection))
      rescue
        false
      end
    end

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
