require 'spec_helper'
describe HotTub do

  context "helpers" do
    describe '#new' do
      it "should return a HotTub::Pool" do
        expect(HotTub::Pool.new { |url| MocClient.new(url) }).to be_a(HotTub::Pool)
      end
    end

    describe '#sessions' do
      it {expect(HotTub.sessions).to be_a(HotTub::Sessions) }
    end

    describe '#add' do
      it "should add a HotTub::Pool to Sessions" do
        HotTub.add("http://test.com") { MocClient.new }

        pool = HotTub.sessions.fetch("http://test.com")

        expect(pool).to be_a(HotTub::Pool)
      end
    end
  end
end
