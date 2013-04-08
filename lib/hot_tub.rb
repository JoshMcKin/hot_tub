require 'thread'
require 'logger'
require "hot_tub/version"
require "hot_tub/known_clients"
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
    (defined?(EM))
  end

  def self.em_synchrony?
    (defined?(EM::Synchrony))
  end

  def self.jruby?
    (defined?(JRUBY_VERSION))
  end

  def self.rbx?
    defined?(RUBY_ENGINE) and RUBY_ENGINE == 'rbx'
  end
end
