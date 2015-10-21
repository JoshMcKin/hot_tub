require 'spec_helper'
describe HotTub::Reaper::Mixin do
  let(:pool) { MocMixinPool.new }

  describe '#reaper' do
    it "should be defined" do
      expect(pool).to respond_to(:reaper)
    end
  end
  describe '#reap_timeout' do
    it "should be defined" do
      expect(pool).to respond_to(:reap_timeout)
    end
  end
  describe '#shutdown' do
    it "should be defined" do
      expect(pool).to respond_to(:shutdown)
    end
  end
  describe '#reap!' do
    it "should be defined" do
      expect(pool).to respond_to(:reap!)
    end
    it "should raise NoMethodError if called" do
      expect { pool.reap! }.to raise_error(NoMethodError)
    end
  end
end
