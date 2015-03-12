require 'spec_helper'
describe HotTub::Reaper::Mixin do
  before(:each) do
    @pool = MocMixinPool.new
  end
  describe '#reaper' do
    it "should be defined" do
      @pool.should respond_to(:reaper)
    end
  end
  describe '#reap_timeout' do
    it "should be defined" do
      @pool.should respond_to(:reap_timeout)
    end
  end
  describe '#shutdown' do
    it "should be defined" do
      @pool.should respond_to(:shutdown)
    end
  end
  describe '#reap!' do
    it "should be defined" do
      @pool.should respond_to(:reap!)
    end
    it "should raise NoMethodError if called" do
      lambda {@pool.reap!}.should raise_error(NoMethodError)
    end
  end
end
