require 'sinatra'
require 'puma'
module HotTub
  class Server < Sinatra::Base

    def self.run
      @events = Puma::Events.new STDOUT, STDERR
      @server = Puma::Server.new HotTub::Server.new, @events
      @server.min_threads = 10
      @server.max_threads = 200
      @server.add_tcp_listener '127.0.0.1', 9595
      @server.run
    end

    set :server, 'puma'
    set :port, 9595

    get '/data/:amount' do |amount|
      (('x' * amount.to_i ) << Random.new.rand(0..999999).to_s)
    end

    def self.teardown
      @server.stop(true) if @server
    end

    def self.size
      10_000
    end

    def self.path
      '/data/' << size.to_s
    end

    def self.url
      'http://127.0.0.1:9595' << path
    end
  end
end