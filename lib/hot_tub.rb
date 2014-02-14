require 'thread'
require 'thread_safe'
require 'logger'
require "hot_tub/version"
require "hot_tub/known_clients"
require "hot_tub/reaper"
require "hot_tub/pool"
require "hot_tub/sessions"

module HotTub
  @@logger = Logger.new(STDOUT)
  def self.logger
    @@logger
  end

  def self.logger=logger
    @@logger = logger
  end

  def self.jruby?
    (defined?(JRUBY_VERSION))
  end

  def self.rbx?
    defined?(RUBY_ENGINE) and RUBY_ENGINE == 'rbx'
  end

  def self.new(opts={},&client_block)
    if opts[:sessions] == false
      Pool.new(opts,&client_block)
    else
      opts[:with_pool] = true unless opts[:pool] == false
      Sessions.new(opts,&client_block)
    end
  end
end
