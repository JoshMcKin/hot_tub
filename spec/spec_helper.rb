require 'hot_tub'
require 'rspec'
require 'bundler/setup'
require 'logger'
require 'excon'
# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
#Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}
HotTub.logger.level = Logger::ERROR

RSpec.configure do |config|

end

class MocClient
  def initialize(url=nil,options={})
    @close = false
    @clean = false
  end

  def get
      sleep(0.05)
  end

  def close
  	@close = true
  end

  def closed?
  	@close == true
  end

  def clean
  	@clean = true
  end

  def cleaned?
  	@clean == true
  end
end
