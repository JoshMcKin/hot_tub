class MocMixinPool
  include HotTub::Reaper::Mixin
end

class MocPool < MocMixinPool
  attr_accessor :reaped, :lets_reap

  def initialize
  	@reaped = false
  	@lets_reap = false
  end

  def reap!
	@reaped = true if @lets_reap
  end
end

class MocReaperPool < MocPool
  def initialize
  	super
    @reaper = HotTub::Reaper.spawn(self)
  end
end