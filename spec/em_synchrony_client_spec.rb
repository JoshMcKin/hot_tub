unless RUBY_VERSION < '1.9' or (defined? RUBY_ENGINE and 'jruby' == RUBY_ENGINE)
  require "em-synchrony"
  require "em-synchrony/em-http"
  require "em-synchrony/fiber_iterator"
  require "hot_tub/clients/em_synchrony_client"
  require 'test_helper_methods'
  include TestHelperMethods

  describe HotTub::EmSynchronyClient do
    before(:each) do
      @url = "https://www.google.com" 
    end

    it "Keep alive should work" do
      EM.synchrony do   
        keep_alive_test HotTub::EmSynchronyClient.new(@url) do |connection| 
          connection.get.response_header.status
        end
        EM.stop
      end
    end
#    context 'integration test with parallel requests' do
#      # 10 parallel requests
#      it "should work" do
#        @connection_pool = HotTub::Session.new(:client_options => 
#            {:url => "https://www.google.com"},
#          :never_block => true,
#          :client => HotTub::EmSynchronyClient)
#        EM.synchrony do       
#          concurrency = 10
#          options = (0..19).to_a
#          results = []
#            
#          EM::Synchrony::FiberIterator.new(options, concurrency).each do |count|
#            resp =  @connection_pool.get
#            results.push resp.response_header.status 
#          end
#            
#          results.length.should eql(20)
#          results.include?(200).should be_true
#          @connection_pool.instance_variable_get(:@pool).length.should eql(@connection_pool.instance_variable_get(:@options)[:size])                
#          EM.stop
#        end
#      end         
#    end
  end
end
