require 'thread'
require "hot_tub/version"
require "hot_tub/known_clients"
require "hot_tub/reaper"
require "hot_tub/pool"
require "hot_tub/sessions"

module HotTub
  GLOBAL_SESSIONS = Sessions.new(:name => "Global Sessions")

  @@logger    = nil
  @@trace     = false
  @@log_trace = false

  def self.logger
    @@logger
  end

  def self.logger=logger
    @@logger = logger
    set_log_trace
  end

  # Set to true for more detail logs
  def self.trace=trace
    @@trace = trace
    set_log_trace
  end

  def self.set_log_trace
    @@log_trace = (!@@logger.nil? && @@trace)
  end

  def self.log_trace?
    @@log_trace
  end

  def self.sessions
    GLOBAL_SESSIONS
  end

  def self.jruby?
    (defined?(JRUBY_VERSION))
  end

  def self.rbx?
    (defined?(RUBY_ENGINE) and RUBY_ENGINE == 'rbx')
  end

  # Resets global sessions, useful in forked environments
  # Does not reset one-off pools or one-off sessions
  def self.reset!
    GLOBAL_SESSIONS.reset!
  end

  # Shuts down global sessions, useful in forked environments
  # Does not shutdown one-off pools or one-off sessions
  def self.shutdown!
    GLOBAL_SESSIONS.shutdown!
  end

  # Adds a new Pool to the global sessions
  def self.add(url,opts={}, &client_block)
    GLOBAL_SESSIONS.add(url, opts, &client_block)
  end

  def self.run(url ,&run_block)
    pool = GLOBAL_SESSIONS.fetch(url)
    pool.run &run_block
  end

  def self.new(opts={}, &client_block)
    Pool.new(opts,&client_block)
  end
end
