require 'spec_helper'
require 'hot_tub/session'
require 'uri'
require 'time'
describe HotTub::Session do

  context 'initialized without a block' do
    it "should raise error if block is not supplied" do
      lambda {HotTub::Session.new}.should raise_error(ArgumentError)
    end
  end
  context 'initialized with a block' do
    before(:each) do
      @url = "https://www.somewebsite.com"
      @uri = URI(@url)
      @sessions = HotTub::Session.new { |url| MocClient.new(url) }
    end

    describe '#to_url' do
      context "passed URL string" do
        it "should return key with URI scheme-domain" do
          @sessions.send(:to_key,@url).should eql("#{@uri.scheme}-#{@uri.host}")
        end
      end

      context "passed URI" do
        it "should return key with URI scheme-domain" do
          @sessions.send(:to_key,@uri).should eql("#{@uri.scheme}-#{@uri.host}")
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
          with_pool_options = HotTub::Session.new { |url| HotTub::Pool.new(:size => 13) { MocClient.new(url) } }
          with_pool_options.sessions(@url)
          sessions = with_pool_options.instance_variable_get(:@sessions)
          sessions.length.should eql(1)
          sessions.first[1].should be_a(HotTub::Pool)
        end
      end

      context 'other clients' do
        it "should add a new client for the url" do
          no_pool = HotTub::Session.new { |url| Excon.new(url) }
          no_pool.sessions(@url)
          sessions = no_pool.instance_variable_get(:@sessions)
          sessions.length.should eql(1)
          sessions.first[1].should be_a(Excon::Connection)
        end
      end

      context "passed URL string" do
        it "should set key with URI scheme-domain" do
          @sessions.sessions(@url)
          sessions = @sessions.instance_variable_get(:@sessions)
          sessions["#{@uri.scheme}-#{@uri.host}"].should be_a(MocClient)
        end
      end
      context "passed URI" do
        it "should set key with URI scheme-domain" do
          @sessions.sessions(@uri)
          sessions = @sessions.instance_variable_get(:@sessions)
          sessions["#{@uri.scheme}-#{@uri.host}"].should be_a(MocClient)
        end
      end
    end

    describe '#run' do
      it "should work" do
        @url = "https://www.somewebsite.com"
        @sessions = HotTub::Session.new { |url| MocClient.new(url) }
        result = nil
        @sessions.run(@url) do |conn|
          result = conn.get
        end
        result.should_not be_nil
      end
    end

    context 'thread safety' do
      it "should work" do
        url = "https://www.somewebsite.com/"
        url2 = "http://www.someotherwebsit.com/"
        session = HotTub::Session.new { |url| MocClient.new(url)}
        failed = false
        start_time = Time.now
        stop_time = nil
        mutex = Mutex.new
        threads = []
        lambda {
          10.times.each do
            threads << Thread.new do
              # MocClient is not thread safe so lets initialize a new instance for each
              session.run(url)  { |clnt| Thread.current[:result] = MocClient.new(url).get }
              session.run(url2) { |clnt| Thread.current[:result] = MocClient.new(url2).get }
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
