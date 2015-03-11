require 'spec_helper'
describe HotTub do

  context "helpers" do
    describe '#new' do

      it "should return a HotTub::Pool" do
        expect(HotTub.new { |url| MocClient.new(url) }).to be_a(HotTub::Pool)
      end

      context ':sessions => true' do
        it "should be a HotTub::Sessions with HotTub::Pool as client" do
          session_with_pool = HotTub.new(:sessions => true)  { |url| MocClient.new(url) }
          pool = session_with_pool.sessions("http://test.com")
          expect(pool).to be_a(HotTub::Pool)
        end
      end
    end
  end
end
