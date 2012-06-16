require 'thread'
require 'timeout'
require 'logger'
require "hot_tub/version"
require "hot_tub/session"
require "hot_tub/clients/client"
require "hot_tub/clients/em_synchrony_client"
require "hot_tub/clients/excon_client"
require "hot_tub/clients/http_client_client" if RUBY_VERSION < '1.9' or (defined? RUBY_ENGINE and 'jruby' == RUBY_ENGINE)

module HotTub
 @@logger = Logger.new(STDOUT)
  def self.logger
    @@logger
  end
  
  def self.logger=logger
    @@logger = logger
  end
end

