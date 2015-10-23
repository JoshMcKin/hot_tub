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

    get '/fast' do
      sleep(0.01)
      "foo"
    end

    get '/slow' do
      sleep(1)
      "foooooooooooo"
    end

    def self.teardown
      @server.stop(true) if @server
    end

    def self.url
      'http://127.0.0.1:9595/fast'
    end

    def self.slow_url
      'http://127.0.0.1:9595/slow'
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

    get '/fast' do
      sleep(0.01)
      "foo"
    end

    def self.teardown
      @server.stop(true) if @server
    end

    def self.url
      'http://127.0.0.1:9393/fast' 
    end
  end
end