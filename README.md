# HotTub [![Build Status](https://travis-ci.org/JoshMcKin/hot_tub.png?branch=master)](https://travis-ci.org/JoshMcKin/hot_tub) [![Coverage Status](https://coveralls.io/repos/JoshMcKin/hot_tub/badge.png?branch=master)](https://coveralls.io/r/JoshMcKin/hot_tub)

Flexible, thread-safe, connection pooling for Ruby. Configurable for any client you desire with built in support for Net::HTTP and [Excon](https://github.com/excon/excon).

### Requirements

HotTub is tested on MRI, JRUBY and Rubinius
* Ruby >= 2.0 # Although older versions may work


## Installation

HotTub is available through [Rubygems](https://rubygems.org/gems/hot_tub) and can be installed via:

    $ gem install hot_tub


### Rails setup

Add hot_tub to your gemfile:
    
    gem 'hot_tub'

Run bundle:
    
    bundle install

Configure Logger by creating `config\initializers\hot_tub.rb` and adding the following:
    
    HotTub.logger = Rails.logger


# Usage 

## Pools Managed by HotTub

HotTub::Sessions are used to manage multiple pools with a single object and using a single reaper. 
A global Sessions object is available from the HotTub module and has several helper methods.
  
    require 'hot_tub'

    # Lets configure HotTub global sessions to use NetHTTP as our default client

    HotTub.default_client = lambda { |url| 
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.start
      http 
    }

    # Add a HotTub::Pool for "https://www.google.com" and use it.
    HotTub.run("https://www.google.com") do |clnt|    
      puts clnt.get('/').code
    end

    # Re-uses the previously defined pool
    HotTub.run("https://www.google.com") do |clnt|    
      puts clnt.get('/').code
    end

    # Add another HotTub::Pool for "https://www.yahoo.com" and use it
    HotTub.run("https://www.yahoo.com") do |clnt|    
      puts clnt.get('/').code
    end

    # We can add more HotTub::Pools with unique settings.
    # Lets add another HotTub::Pool of Excon clients with a pool size of 12.
    # HotTub.stage sets the options passed to a settings cache, the pool is
    # created the first time we call HotTub.run. We are not setting :max_size 
    # so our connections will grow to match our currency. Once load dies down 
    # our pool will be reaped back down to 12 connections

    HotTub.stage('excon_yahoo', { :size => 12} ) do
     Excon.new("https://yahoo.com", :thread_safe_sockets => false )
    end

    # Lets add Redis too. HotTub.add returns the pool created for that key so we
    # can store that in an constant for easy access.
    # We don't want too many connections so we set our :max_size. Under load our pool
    # can grow to 30 connections. Once load dies down our pool can be reaped back down to 5

    REDIS = HotTub.add("redis", :size => 5, :max_size => 30) { Redis.new } 
      
    # Now we can call any of our pools using the key we set.

    HotTub.run('excon_yahoo') do |clnt|    
      puts clnt.get.status
    end

    # Since our REDIS constant was set to HotTub::Pool instance return from HotTub.add 
    # we do not need the key when calling #run
    REDIS.run do |clnt|
      clnt.set('hot', 'stuff')
    end

    # Re-use "https://www.google.com" we created earlier
    HotTub.run("https://www.google.com") do |clnt|    
      puts clnt.get('/').code
    end


## Single Pool
    
    pool = HotTub::Pool.new(:size => 5, :max_size => 30, :reap_timeout => 60) { Redis.new }

    pool.run |clnt|
     clnt.set('hot', 'stuff')
    end

    pool.run |clnt|
      pool.get('hot')
    end


## Connection Life Cycles

HotTub has built in support for closing NetHTTP and Excon. If you need more control or have 
a different library you would like to use, HotTub can be configured to support your needs 
using `:close`, `:clean`, and `:reap?` options in a pools settings, and each option can accept
a lambda that accepts the client as an argument or symbol representing a method to call on the client.

`:close` is used to define how a connections should be closed at shutdown and upon reaping.

`:clean` is called on each existing connection as its pulled from the pool.

`:reap?` is used to determine if a connection in the pool is ready for reaping.

    pool_options = {
      :size     => 5
      :max_size => 10
      :close    => :close
      :clean    => lambda { |clnt| clnt.reconnect if clnt.dirty? },
      :reap?    => :stale? # returns truthy if we want to reap
    }

    HotTub.add('offBrand', pool_options) { MyCoolClient.new }
    # or
    HotTub::Pool.new(pool_options){ MyCoolClient.new }


## Forking

HotTub's `#reset!` methods close all idle connections, prevents connections in use from returning
to the pool and attempts to close orphaned connections as they attempt to return.

    # Puma
    on_worker_boot do

      # If you let HotTub manage all your connections
      HotTub.reset!

      # If you have your own HotTub::Sessions
      MY_SESSIONS.reset!

      # If you have any one-off pools
      MY_POOL.reset!

    end

    # Unicorn
    before_fork do |server, worker|

      # If you let HotTub manage all your connections
      HotTub.reset!

      # If you have your own HotTub::Sessions
      MY_SESSIONS.reset!

      # If you have any one-off pools
      MY_POOL.reset!
    end


## Contributing to HotTub
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.