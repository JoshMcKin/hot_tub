# HotTub [![Build Status](https://travis-ci.org/JoshMcKin/hot_tub.png?branch=master)](https://travis-ci.org/JoshMcKin/hot_tub) [![Coverage Status](https://coveralls.io/repos/JoshMcKin/hot_tub/badge.png?branch=master)](https://coveralls.io/r/JoshMcKin/hot_tub)

Flexible, thread-safe, connection pooling for Ruby. Configurable for any client you desire. Built in reaper th built in support for Net::HTTP and [Excon](https://github.com/excon/excon).

## Features

### HotTub::Pool

* Thread safe
* Lazy, pool starts off at 0 and grows as necessary.
* Non-Blocking, can be configured to always return a connection if your pool runs out under load. Overflow connections are returned to the pool for reuse. Once load dies, the pool is reaped down to size.
* Support for cleaning dirty resources, no one likes a dirty `HotTub`
* Support for closing resources on shutdown
* Support for process forking


### HotTub::Sessions

A synchronized hash where keys are mapped to a HotTub::Pools that are managed by a single HotTub::Reaper.


### HotTub::Reaper

A separate thread thats manages your pool(s). All HotTub::Pools managed by HotTub::Sessions share a single reaper. One-off HotTub::Pools have their own reaper. The reaper periodically checks pool(s) based on the `:reap_timeout` set for the pool or session. Over-flow connections or connections deemed reap-able ready are pulled from the pool and closed.


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
    require 'net/http'
    require 'excon'
    require 'redis'

    # Add a HotTub::Pool of Net::HTTP connections to our sessions with a size of 12.
    # We are using the url as the key but could use anything.
    # we are not setting :max_size so our connections will grow to match our currency.
    # Once load dies down our pool will be reaped back down to 12 connections

    URL = "https://google.com"
    pool = HotTub.get_or_set(URL, { :size => 12 }) do 
      uri = URI.parse(URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.start
      http 
    end

    # A separate HotTub::Pool of Excon connections.

    HotTub.get_or_set('yahoo', { :size => 5 }) { Excon.new("https://yahoo.com") }

    # Lets add Redis too. HotTub.add returns the pool created for that key so we
    # can store that in an constant for easy access.
    # We don't want too many connections so we set our :max_size. Under load our pool
    # can grow to 30 connections. Once load dies down our pool can be reaped back down to 5

    REDIS = HotTub.get_or_set("redis", :size => 5, :max_size => 30) { Redis.new } 
      
    # Now we can call any of our pools using the key we set any where in our code.

    HotTub.run(url) do |clnt|    
      puts clnt.head('/').code
    end

    HotTub.run('yahoo') do |clnt|    
      puts clnt.get(:path => "/some_stuff", :query => {:foo => 'bar'}).body
    end

    # Since our REDIS contast was set to HotTub::Pool instance return from HotTub.add 
    # we do not need the key when calling #run
    REDIS.run do |clnt|
      clnt.set('hot', 'stuff')
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
using `:close`, `:clean`, and `:reap?` options in a pools settings.

`:close` is used to define how a connections should be closed at shutdown and upon reaping.
reaped.

`:clean` is called on each existing connection as its pulled from the pool.

`:reap?` is used to determine if a connection in the pool is ready for reaping.

EX:
    pool_options = {
      :size     => 5
      :max_size => 10
      :close    => lambda { |clnt| clnt.close_it }, # could also use :close_id symbol instead of a lambda
      :clean    => lambda { |clnt| clnt.reconnect if clnt.dirty? },
      :reap?    => lambda { |clnt| clnt.stail? }
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