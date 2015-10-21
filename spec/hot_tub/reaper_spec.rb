require 'spec_helper'

describe HotTub::Reaper do
  
  let(:pool) { MocReaperPool.new }
  let(:reaper) { pool.reaper }

  it "should be a HotTub::Reaper Thread" do
    expect(reaper).to be_a(Thread)
  end

  it "should reap!" do
    expect(pool.reaped).to eql(false)
    pool.lets_reap = true
    reaper.wakeup
    sleep(0.01)
    expect(pool.reaped).to eql(true)
  end

  it "should sleep after reap!" do
    expect(pool.reaped).to eql(false)
    pool.lets_reap = true
    reaper.wakeup
    sleep(0.01)
    expect(reaper.status).to eql('sleep')
  end
end
