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
      0.2
    end
  end
end