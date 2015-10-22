require 'sinatra'
require 'puma'
module HotTub
  class Server < Sinatra::Base

    def self.run
      @events = Puma::Events.new STDOUT, STDERR
      @server = Puma::Server.new HotTub::Server.new, @events
      @server.min_threads = 10
      @server.max_threads = 100
      @server.add_tcp_listener '127.0.0.1', 9595
      @server.run
    end

    set :server, 'puma'
    set :port, 9595

    get '/data' do
      sleep(0.01)
      "foo"
    end

    def self.teardown
      @server.stop(true) if @server
    end

    def self.url
      'http://127.0.0.1:9595/data'
    end
  end

  class Server2 < Sinatra::Base

    def self.run
      @events = Puma::Events.new STDOUT, STDERR
      @server = Puma::Server.new HotTub::Server.new, @events
      @server.min_threads = 0
      @server.max_threads = 20
      @server.add_tcp_listener '127.0.0.1', 9393
      @server.run
    end

    set :server, 'puma'
    set :port, 9393

    get '/foo' do
      sleep(0.01)
      "foo"
    end

    def self.teardown
      @server.stop(true) if @server
    end

    def self.url
      'http://127.0.0.1:9393/foo' 
    end
  end
end