require 'thread'
require 'timeout'
require 'logger'
require "hot_tub/version"
require "hot_tub/pool"
require "hot_tub/session"

module HotTub
  @@logger = Logger.new(STDOUT)
  def self.logger
    @@logger
  end

  def self.logger=logger
    @@logger = logger
  end

  def self.em?
    (defined?(EM) && EM::reactor_running?)
  end

  def self.jruby?
    (defined?(JRUBY_VERSION))
  end
end
