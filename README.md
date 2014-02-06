# HotTub [![Build Status](https://travis-ci.org/JoshMcKin/hot_tub.png?branch=master)](https://travis-ci.org/JoshMcKin/hot_tub) [![Coverage Status](https://coveralls.io/repos/JoshMcKin/hot_tub/badge.png?branch=master)](https://coveralls.io/r/JoshMcKin/hot_tub)

A simple thread-safe connection pool and sessions gem. 

## Features

### HotTub::Pool
* Thread safe
* Lazy clients/connections (created only when necessary)
* Can be used with any client library
* Support for cleaning dirty resources
* Set to expand pool under load that is eventually reaped back down to set size (never_block), can be disabled
* Attempts to close clients/connections on shutdown

### HotTub::Session
* Thread safe
* The same api as HotTub::Pool
* Can be used with HotTub::Pool or any client library 
* Attempts to close clients/connections on shutdown

## Requirements
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

Configure Logger by creating a hot_tub.rb initializer and adding the following:
    
    HotTub.logger = Rails.logger

# Usage 

## HotTub::Pool

### Net::HTTP
    require 'hot_tub'
    require 'net/http'
    pool = HotTub::Pool.new(:size => 10) { 
      uri = URI.parse("http://somewebservice.com")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.start
      http
      }
    pool.run {|clnt| puts clnt.head('/').code }

### Other
You can use any library you want with HotTub::Pool. Close and clean can be defined at initialization 
with lambdas, if they are not defined they are ignored.

    url = "http://test12345.com"
    pool = HotTub::Pool.new({:size => 10, :close => lambda {|clnt| clnt.close}}) { MyHttpLib.new }
    pool.run { |clnt| clnt.get(url,query).body }
 
## HotTub::Session
HotTub::Session is a ThreadSafe::Cache where URLs are mapped to clients or pools. 
For example, [Excon](https://github.com/geemus/excon) is thread safe but you set a single url at the client level so sessions 
are handy if you need to access multiple urls but would prefer a single object.
    
    require 'hot_tub'
    require 'excon'
    # Our client block must accept the url argument
    sessions = HotTub::Session.new {|url| Excon.new(url) }

    sessions.run("http://somewebservice.com") do |clnt|    
      puts clnt.get(:query => {:some => 'stuff'}).response_header.status
    end

    sessions.run("https://someotherwebservice.com") do |clnt|    
      puts clnt.get(:query => {:other => 'stuff'}).response_header.status
    end

### HotTub::Session with HotTub::Pool
Suppose you have a client that lacks pooling and session features you can use HotTub::Pool with HotTub::Sessions to get what you need.
    
    require 'hot_tub'
    require 'net/http'

    # We must tell HotTub::Session to use HotTub::Pool, pass any pool options in our 
    # options has, and our client block must accept the url argument
    sessions = HotTub::Session.new(:with_pool => true, :size => 12) { |url| 
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.start
      http 
    }
    sessions.run("http://somewebservice.com") do |clnt|    
      puts clnt.head('/').code
    end
    sessions.run("https://someotherwebservice.com") do |clnt|    
      puts clnt.head('/').code
    end

## Other Pooling Gem

* [ConnectionPool](https://github.com/mperham/connection_pool)

## Contributing to HotTub
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.