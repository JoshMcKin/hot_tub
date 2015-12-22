require 'spec_helper'

describe HotTub::Reaper do

  let(:pool)    { MocReaperPool.new }
  let(:reaper)  { pool.reaper }

  it "should be a HotTub::Reaper Thread" do
    expect(reaper.thread).to be_a(Thread)
  end

  it "should reap!" do
    pool.wait_for_reap
    expect(pool.reaped).to eql(true)
  end

  it "should still be alive" do
    pool.wait_for_reap
    expect(reaper).to be_alive
  end
end
