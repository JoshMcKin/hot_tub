require 'spec_helper'

describe HotTub::Reaper do
  before(:each) do
    @pool = MocReaperPool.new
    @reaper = @pool.reaper
  end
  it "should be a HotTub::Reaper Thread" do
  	@reaper.should be_a(HotTub::Reaper)
    @reaper.should be_a(Thread)
  end

  it "should reap!" do
  	@pool.reaped.should be_false
  	@pool.lets_reap = true
  	@reaper.wakeup
  	sleep(0.01)
  	@pool.reaped.should be_true
  end

  it "should sleep after reap!" do
  	@pool.reaped.should be_false
  	@pool.lets_reap = true
  	@reaper.wakeup
  	sleep(0.01)
  	@reaper.status.should eql('sleep')
  end
end
