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
    @lets_reap = false
  end
end

class MocReaperPool < MocPool
  def initialize
    super
    @reap_timeout = 0.01
    @reaper = HotTub::Reaper.spawn(self)
  end

  def reap!
    if @lets_reap
      @lets_reap.call
      @reaped = true
      @lets_reap = nil
    end
  end
end
