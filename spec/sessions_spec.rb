require 'spec_helper'
require 'hot_tub/sessions'
require 'uri'
require 'time'
describe HotTub::Session do

  context 'initialized without a block' do
    it "should raise error if block is not supplied" do
      lambda {HotTub::Sessions.new}.should raise_error(ArgumentError)
    end
  end
  context 'initialized with a block' do
    before(:each) do
      @url = "https://www.somewebsite.com"
      @uri = URI(@url)
      @sessions = HotTub::Sessions.new { |url| MocClient.new(url) }
    end

    describe '#to_url' do
      context "passed URL string" do
        it "should return key with URI scheme-domain" do
          @sessions.send(:to_key,@url).should eql("#{@uri.scheme}://#{@uri.host}:#{@uri.port}")
        end
      end

      context "passed URI" do
        it "should return key with URI scheme-domain" do
          @sessions.send(:to_key,@uri).should eql("#{@uri.scheme}://#{@uri.host}:#{@uri.port}")
        end
      end

      context "invalid argument" do
        it "should raise an ArgumentError" do
          lambda { @sessions.send(:to_key, nil) }.should raise_error(ArgumentError)
        end
        it  "should raise URI::InvalidURIError with bad url" do
          lambda { @sessions.send(:to_key,"bad url") }.should raise_error(URI::InvalidURIError)
        end
      end
    end

    describe '#sessions' do
      context 'HotTub::Pool as client' do
        it "should add a new client for the url" do
          with_pool_options = HotTub::Sessions.new { |url| HotTub::Pool.new(:size => 13) { MocClient.new(url) } }
          with_pool_options.sessions(@url)
          sessions = with_pool_options.instance_variable_get(:@sessions)
          sessions.size.should eql(1)
          sessions.each_value {|v| v.should be_a( HotTub::Pool)}
        end
      end

      context 'other clients' do
        it "should add a new client for the url" do
          no_pool = HotTub::Sessions.new { |url| Excon.new(url) }
          no_pool.sessions(@url)
          sessions = no_pool.instance_variable_get(:@sessions)
          sessions.size.should eql(1)
          sessions.each_value {|v| v.should be_a(Excon::Connection)}
        end
      end

      context "passed URL string" do
        it "should set key with URI scheme-domain" do
          @sessions.sessions(@url)
          sessions = @sessions.instance_variable_get(:@sessions)
          sessions["#{@uri.scheme}://#{@uri.host}:#{@uri.port}"].should be_a(MocClient)
        end
      end
      context "passed URI" do
        it "should set key with URI scheme-domain" do
          @sessions.sessions(@uri)
          sessions = @sessions.instance_variable_get(:@sessions)
          sessions["#{@uri.scheme}://#{@uri.host}:#{@uri.port}"].should be_a(MocClient)
        end
      end

      context "with_pool" do
        it "should initialize a new HotTub::Pool" do
          session_with_pool = HotTub::Sessions.new({:with_pool => true})  { |url| MocClient.new(url) }
          pool = session_with_pool.sessions(@url)
          pool.should be_a(HotTub::Pool)
        end
      end
    end

    describe '#run' do
      it "should work" do
        url = HotTub::Server.url
        sessions = HotTub::Sessions.new { |url| Excon.new(url) }
        result = nil
        sessions.run(url) do |conn|
          result = conn.get.status
        end
        result.should eql(200)
      end

      context "with_pool" do
        it "should pass run to pool" do
          url = HotTub::Server.url
          session_with_pool = HotTub::Sessions.new({:with_pool => true})  { |url|
            uri = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = false
            http.start
            http
          }
          result = nil
          session_with_pool.run(url) do |conn|
            uri = URI.parse(url)
            result = conn.get(uri.path).code
          end
          result.should eql('200')
        end
      end
    end

    context 'threads' do
      it "should work" do
        url = HotTub::Server.url
        url2 = HotTub::Server2.url
        session = HotTub::Sessions.new(:with_pool => true) { |url|
            uri = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = false
            http.start
            http
          }
        failed = false
        start_time = Time.now
        stop_time = nil
        threads = []
        lambda {
          10.times.each do
            threads << Thread.new do
              session.run(url)  { |clnt| Thread.current[:result] = clnt.get(URI.parse(url).path).code }
              session.run(url2) { |clnt| Thread.current[:result] = clnt.get(URI.parse(url).path).code }
            end
          end
          threads.each do |t|
            t.join
          end
          stop_time = Time.now
        }.should_not raise_error # make sure we're thread safe
        # Some extra checks just to make sure...
        results = threads.collect{ |t| t[:result]}
        results.length.should eql(10) # make sure all threads are present
        results.uniq.should eql([results.first]) # make sure we got the same results
        ((stop_time.to_i - start_time.to_i) < (results.length * MocClient.sleep_time)).should be_true # make sure IO is running parallel
        session.instance_variable_get(:@sessions).keys.length.should eql(2) # make sure sessions were created
      end
    end
  end
end
