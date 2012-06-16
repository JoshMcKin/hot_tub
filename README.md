# HotTub
A simple thread-safe pooling gem to use with your preferred http library that support
keep-alive.

## Installation

HotTub is available through [Rubygems](https://rubygems.org/gems/hot_tub) and can be installed via:

    $ gem install hot_tub

## Setup 
    class MyClass
      @@pool = HotTub::Session.new({:size => 2 :client => HotTub::Client::EmSynchronyClient.new('https://google.com'), :never_block => true})

      def self.fetch_results(query)
        @@pool.get(:query => query) # keepalive has be defaulted to true in the client
      end
    end

    MyClass.fetch_results({:foo => "goo"})

## Contributing to HotTub
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.