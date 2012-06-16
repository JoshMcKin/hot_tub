unless (RUBY_VERSION < '1.9' or (defined? RUBY_ENGINE and 'jruby' == RUBY_ENGINE))
  require "hot_tub/clients/excon_client"
  require 'test_helper_methods'
  require 'excon'
  include TestHelperMethods
  describe HotTub::ExconClient do
    before(:each) do
      @url = "https://www.google.com"
    end
  
    it "Keep alive should work" do
      keep_alive_test HotTub::ExconClient.new(@url) do |client| 
        client.get.status
      end
    end
  end
end

