require 'spec_helper'

describe HotTub::Reaper do

  let(:pool)    { MocReaperPool.new }
  let(:reaper)  { pool.reaper }
  let(:mx)      { Mutex.new }
  let(:cv)      { ConditionVariable.new }

  it "should be a HotTub::Reaper Thread" do
    expect(reaper.thread).to be_a(Thread)
  end

  it "should reap!" do
    expect(pool.reaped).to eql(false)
    mx.synchronize do
      pool.lets_reap = lambda {
        mx.synchronize do
          cv.signal
        end
      }
      cv.wait(mx)
    end
    expect(pool.reaped).to eql(true)
  end

  it "should be alive after reap!" do
    expect(pool.reaped).to eql(false)
    mx.synchronize do
      pool.lets_reap = lambda {
        mx.synchronize do
          cv.signal
        end
      }
      cv.wait(mx)
    end
    expect(reaper).to be_alive
  end
end
