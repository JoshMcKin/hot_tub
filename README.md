# HotTub [![Build Status](https://travis-ci.org/JoshMcKin/hot_tub.png?branch=master)](https://travis-ci.org/JoshMcKin/hot_tub)
A simple thread-safe connection pooling gem. Out-of-the-box support for [Excon](https://github.com/geemus/excon) and
[EM-Http-Requests](https://github.com/igrigorik/em-http-request) via [EM-Synchrony](https://github.com/igrigorik/em-synchrony). 
There are a couple Ruby connection pool libraries out there but HotTub differs from most in that its connections are lazy 
(created only when necessary), accomidates libraries that do not clean their dirty connections automatically, and manages unexpected usage increases by opening new connections rather than just blocking or throwing exceptions (never_block), although never_block can be disabled. 

## Installation

HotTub is available through [Rubygems](https://rubygems.org/gems/hot_tub) and can be installed via:

    $ gem install hot_tub

## Usage 

### Excon

    require 'excon'
    class MyClass
      @@url = "http://test12345.com"
      @@pool = HotTub::Pool.new({:size => 10}) { Excon.new("http://somewebservice.com") }
      def self.fetch_results(url,query={})
        @@pool.run |connection|
          connection.get(:query => query).body
        end
      end
    end
    MyClass.fetch_results({:foo => "goo"}) # => "Some reponse"

### EM-Http-Request

    require "em-synchrony"
    require "em-synchrony/em-http"
    class EMClass
      @@pool = HotTub::Pool.new(:size => 12) { EM::HttpRequest.new("http://somewebservice.com") }
      def async_post_results(query = {})
        @@pool.run do |connection|    
          connection.aget(:query => results, :keepalive => true)
        end
      end
    end

    EM.synchrony do {
      EMClass.async_fetch_results({:foo => "goo"})
      EM.stop
    }

### Other
 You can use any libary you want. Close and clean can be defined at initialization with
 lambdas, if they are not defined they are ignored.

    require 'excon'
    class MyClass
      @@url = "http://test12345.com"
      @@pool = HotTub::Pool.new({:size => 10, :close => lambda {|clnt| clnt.close}}) { MyHttpLib.new }
      def self.fetch_results(url,query={})
        @@pool.run |connection|
          connection.get(@@url,query).body
        end
      end
    end

    MyClass.fetch_results({:foo => "goo"}) # => "Some reponse"

## Sessions with Pool
Not all clients have a sessions feature, Excon and Em-Http-Request clients are initialized to a single domain and while you
can change paths the client domain cannot change. HotTub::Session allows you create a session object that initializes
seperate pools for your various domains based on URI.

    require 'excon'
    class MyClass
      # Our client block must accept the url argument
      @@sessons = HotTub::Sessions.new {|url| { Excon.new(url) } 
      def async_post_results(query = {})
        @@sessons.run("http://somewebservice.com") do |connection|    
          puts connection.run(:query => results).response_header.status
        end
        @@sessons.run("https://someotherwebservice.com") do |connection|    
          puts connection.get(:query => results).response_header.status
        end
      end
    end

## Sessions without Pool
If you have a client that is thread safe but does not support sessions you can implement sessions similarly.

    class MyClass
      # Our client block must accept the url argument
      @@sessons = HotTub::Sessions.new(:with_pool => false) {|url| MyThreadSafeLib.new(url) }
      def async_post_results(query = {})
        @@sessons.run("http://somewebservice.com") do |connection|    
          puts connection.get(:query => results).response_header.status
        end
        @@sessons.run("https://someotherwebservice.com") do |connection|    
          puts connection.get(:query => results).response_header.status
        end
      end
    end

## Related

* [EM-Http-Request](https://github.com/igrigorik/em-http-request)
* [EM-Synchrony](https://github.com/igrigorik/em-synchrony)
* [Excon](https://github.com/geemus/excon)
* [HTTPClient](https://github.com/nahi/httpclient) A thread safe http client that supports sessions all by itself.

## Other Pooling Gem

* [ConnectionPool](https://github.com/mperham/connection_pool)
* [EM-Synchrony](https://github.com/igrigorik/em-synchrony) has a connection pool feature

## Contributing to HotTub
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.