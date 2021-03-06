require 'hot_tub'
require 'rspec'
require 'bundler/setup'
require 'logger'
require 'excon'
require 'helpers/moc_pool'
require 'helpers/moc_client'
require 'helpers/server'
require 'net/https'

begin
  require 'byebug'
rescue LoadError
end

unless HotTub.jruby? || HotTub.rbx?
  require 'coveralls'
  Coveralls.wear!
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
# Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}
# HotTub.logger = Logger.new(STDOUT)
# HotTub.trace = true

RSpec.configure do |config|
  config.before(:suite) do
    HotTub::Server.run
    HotTub::Server2.run
  end
  config.after(:suite) do
    HotTub::Server.teardown
    HotTub::Server2.teardown
  end
end
