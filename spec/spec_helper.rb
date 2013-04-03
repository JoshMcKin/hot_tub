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

  # Perform an IO
  def get
    return `sleep #{self.class.sleep_time}; echo "that was slow IO"`
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

  class << self
    def sleep_time
      0.5
    end
  end
end
