require 'hot_tub'
require 'rspec'
require 'bundler/setup'
require 'logger'
require 'excon'
require 'helpers/moc_client'
require 'helpers/server'
# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
#Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}
HotTub.logger.level = Logger::ERROR

RSpec.configure do |config|
 config.before(:suite) do
  HotTub::Server.run
 end
 config.after(:suite) do
  HotTub::Server.teardown
 end
end