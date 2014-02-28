# HotTub [![Build Status](https://travis-ci.org/JoshMcKin/hot_tub.png?branch=master)](https://travis-ci.org/JoshMcKin/hot_tub) [![Coverage Status](https://coveralls.io/repos/JoshMcKin/hot_tub/badge.png?branch=master)](https://coveralls.io/r/JoshMcKin/hot_tub)

A flexible thread-safe pooling gem. When you need more than a standard static pool.

## Features

### HotTub::Pool
A thread safe, lazy pool.

* Thread safe
* Lazy, pool starts off at 0 and grows as necessary.
* Non-Blocking, can be configured to always return a client if your pool runs out under load. Overflow clients are returned to the pool for reuse. Once load dies, the pool is reaped down to size.
* Can be used with any client library instance.
* Support for cleaning dirty resources, no one likes a dirty `HotTub`
* Support for closing resources on shutdown

### HotTub::Sessions
A [ThreadSafe::Cache](https://github.com/headius/thread_safe) where URLs are mapped to a pool or client instance.

### Requirements
HotTub is tested on MRI, JRUBY and Rubinius
* Ruby >= 1.9

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

## HotTub
For convenience you can initialize a new HotTub::Pool by calling HotTub.new or HotTub::Pool.new directly.
Returns an instance of HotTub::Pool.

### Redis
    # We don't want too many connections so we set our :max_size. Under load our pool
    # can grow to 30 connections. Once load dies down our pool can be reaped back down to 5
    pool = HotTub::Pool.new(:size => 5, :max_size => 30, :reap_timeout => 60) { Redis.new }
    pool.set('hot', 'stuff')
    pool.get('hot')
    # => 'stuff'

### Net::HTTP

    require 'hot_tub'
    require 'net/http'

    pool = HotTub.new(:size => 10) { 
      uri = URI.parse("http://somewebservice.com")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.start
      http
      }
    pool.run {|clnt| puts clnt.head('/').code }

### HotTub Options    
**size**: Default is 5. An integer that sets the size of the pool. Could be describe as minimum size the pool should grow to.

**max_size**: Default is 0. An integer that represents the maximum number of connections allowed when :non_blocking is true. If set to 0, which is the default, there is no limit; connections will continue to open until load subsides long enough for reaping to occur.

**wait_timeout**: Default is 10 seconds. An integer that represents the timeout when waiting for a client from the pool in seconds. After said time a HotTub::Pool::Timeout exception will be thrown

**reap_timeout**: Default is 600 seconds. An integer that represents the timeout for reaping the pool in seconds.

**close_out**: Default is false. A boolean value that if true force close_client to be called on checkout clients when #drain! is called

**close**: Default is nil. Can be a symbol representing an method to call on a client to close the client or a lambda that accepts the client as a parameter that will close a client. The close option is performed on clients on reaping and shutdown after the client has been removed from the pool.  When nil, as is the default, no action is performed.

**clean**: Default is nil. Can be a symbol representing an method to call on a client to clean the client or a lambda that accepts the client as a parameter that will clean a client. When nil, as is the default, no action is performed.

**reap**: Default is nil. Can be a symbol representing an method to call on a client that returns a boolean marking a client for reaping, or a lambda that accepts the client as a parameter that returns a boolean  marking a client for reaping. When nil, as is the default, no action is performed.

**no_reaper**: Default is nil. A boolean like value that if true prevents the reaper from initializing

**sessions**: Default is false. Returns an instance of `HotTub::Sessions.new` that wraps clients in `HotTub::Pool.new`

### With sessions
Available via `HotTub.new(:sessions => true)` or `HotTub::Sessions.new`

    require 'hot_tub'
    require 'net/http'

    # We must pass any pool options in our options hash, and our client block 
    # must accept the a single argument which is normally the url

    hot_tub = HotTub.new(:size => 12, :sessions => true) { |url| 
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.start
      http 
    }
    hot_tub.run("http://somewebservice.com") do |clnt|    
      puts clnt.head('/').code
    end
    hot_tub.run("https://someotherwebservice.com") do |clnt|    
      puts clnt.head('/').code
    end

### Other
You can use any library you want with `HotTub::Pool`.

    url = "http://test12345.com"
    hot_tub = HotTub.new({:size => 10, :close => lambda {|clnt| clnt.close}, :clean => :clean, :reap => :reap?}) { MyHttpLib.new }
    hot_tub.run { |clnt| clnt.get(url,query).body }

## Sessions only
Returns a `HotTub::Sessions` instance. 

[Excon](https://github.com/geemus/excon) is thread safe but you set a single url at the client level so sessions 
are handy if you need to access multiple URLs from a single instances
    
    require 'hot_tub'
    require 'excon'
    # Our client block must accept the url argument
    sessions = HotTub::Sessions.new {|url| Excon.new(url) }

    sessions.run("http://somewebservice.com") do |clnt|    
      puts clnt.get(:query => {:some => 'stuff'}).response_header.status
    end

    sessions.run("https://someotherwebservice.com") do |clnt|    
      puts clnt.get(:query => {:other => 'stuff'}).response_header.status
    end

## Dependencies

* [ThreadSafe](https://github.com/headius/thread_safe)

## Contributing to HotTub
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.