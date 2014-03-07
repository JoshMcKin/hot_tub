class MocClient
  def initialize(url=nil,options={})
    @reaped = false
    @close = false
    @clean = false
  end

  # Perform an IO
  def get
    prng = Random.new()
    t_s = "0.0#{prng.rand(1..9)}".to_f
    sleep(t_s)
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
end