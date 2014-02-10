require 'spec_helper'
describe HotTub do

  context "helpers" do
    describe '#new' do
    	
      it "should return a HotTub::Session" do
        (HotTub.new { |url| MocClient.new(url) }).should be_a(HotTub::Session)
      end

      it "should be a HotTub::Sessions with HotTub::Pool as client" do
        session_with_pool = HotTub.new()  { |url| MocClient.new(url) }
        pool = session_with_pool.sessions("http://test.com")
        pool.should be_a(HotTub::Pool)
      end

      context ':pool => false' do
        it "should be a HotTub::Sessions with MocClient as client" do
          session_with_pool = HotTub.new(:pool => false)  { |url| MocClient.new(url) }
          pool = session_with_pool.sessions("http://test.com")
          pool.should be_a(MocClient)
        end
      end

      context ':sessions => false' do
        it "should be a HotTub::Sessions with MocClient as client" do
          (HotTub.new(:sessions => false) { |url| MocClient.new(url) }).should be_a(HotTub::Pool)
        end
      end
    end
  end
end
