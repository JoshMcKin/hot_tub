if RUBY_VERSION < '1.9' or (defined? RUBY_ENGINE and 'jruby' == RUBY_ENGINE)
  require "hot_tub/clients/http_client_client"
  require 'test_helper_methods'
  include TestHelperMethods
  describe HotTub::HttpClientClient do
    before(:each) do
      @url = "https://www.google.com"
    end 
    it "Keep alive should work" do
      keep_alive_test HotTub::HttpClientClient.new(:url => @url) do |client| 
        c = client.get('')
        c.status_code
      end
    end
  end
end