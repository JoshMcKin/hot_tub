class MocClient
  def initialize(url=nil,options={})
    @reaped = false
    @close = false
    @clean = false
  end

  # Perform an IO
  def get
    sleep(self.class.sleep_time)
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

  def reap
    @reaped = true
  end

  def reaped?
    @reaped
  end

  class << self
    def sleep_time
      0.1
    end
  end
end