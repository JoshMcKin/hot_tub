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
  attr_accessor :mx, :cv, :reaped
  def initialize
    super
    @reap_timeout = 0.01
    
    @mx  = Mutex.new
    @cv  =  ConditionVariable.new
    @reaped = false

    @reaper = HotTub::Reaper.spawn(self)
  end

  def wait_for_reap
    @mx.synchronize do
      @cv.wait(@mx)
    end
  end

  def reap!
    @mx.synchronize do
      @reaped = true
      @cv.signal
    end
  end
end
