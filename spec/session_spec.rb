require 'spec_helper'
require 'hot_tub/session'
require 'uri'
require 'time'
unless HotTub.jruby?
  require "em-synchrony"
  require "em-synchrony/em-http"
end
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
          session_with_pool = HotTub::Session.new({:with_pool => true})  { |url| MocClient.new(url) }
          pool = session_with_pool.sessions(@url)
          pool.should be_a(HotTub::Pool)
        end
      end
    end

    describe '#run' do
      it "should work" do
        url = HotTub::Server.url
        sessions = HotTub::Session.new { |url| Excon.new(url) }
        result = nil
        sessions.run(url) do |conn|
          result = conn.get.status
        end
        result.should eql(200)
      end

      context "with_pool" do
        it "should pass run to pool" do
          url = HotTub::Server.url
          session_with_pool = HotTub::Session.new({:with_pool => true})  { |url| Excon.new(url) }
          result = nil
          session_with_pool.run(url) do |conn|
            result = conn.get.status
          end
          result.should eql(200)
        end
      end
    end

    context 'threads' do
      it "should work" do
        url = HotTub::Server.url
        url2 = HotTub::Server2.url
        session = HotTub::Session.new(:with_pool => true) { |url| Excon.new(url)}
        failed = false
        start_time = Time.now
        stop_time = nil
        threads = []
        lambda {
          10.times.each do
            threads << Thread.new do
              # MocClient is not thread safe so lets initialize a new instance for each
              session.run(url)  { |clnt| Thread.current[:result] = clnt.get.status }
              session.run(url2) { |clnt| Thread.current[:result] = clnt.get.status }
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

    unless HotTub.jruby?

      describe "fiber_mutex?" do

        context 'EM::HttpRequest as client' do
          before(:each) do
            @session = HotTub::Session.new {|url| EM::HttpRequest.new(url)}
          end
          context "EM::Synchrony is present" do
            it "should be true" do
              HotTub.stub(:em_synchrony?).and_return(true)
              @session.send(:fiber_mutex?).should be_true
            end
          end
          context "EM::Synchrony is not present" do
            it "should be false" do
              HotTub.stub(:em_synchrony?).and_return(false)
              @session.send(:fiber_mutex?).should be_false
            end
          end
        end
        context 'client is not EM::HttpRequest' do
          it "should be false" do
            session = HotTub::Session.new {|url| MocClient.new}
            session.send(:fiber_mutex?).should be_false
          end
        end
      end

      context 'fibers' do
        it "should work" do
          EM.synchrony do
            sessions = HotTub::Session.new(:with_pool => true) {|url| EM::HttpRequest.new(url)}
            failed = false
            fibers = []
            lambda {
              10.times.each do
                fibers << Fiber.new do
                  sessions.run(@url) {|connection|
                    s = connection.head(:keepalive => true).response_header.status
                  failed = true unless s == 200}
                end
              end
              fibers.each do |f|
                f.resume
              end
              loop do
                done = true
                fibers.each do |f|
                  done = false if f.alive?
                end
                if done
                  break
                else
                  EM::Synchrony.sleep(0.01)
                end
              end
            }.should_not raise_error
            sessions.instance_variable_get(:@sessions).keys.length.should eql(1)
            (sessions.sessions(@url).instance_variable_get(:@pool).length >= 5).should be_true #make sure work got done
            failed.should be_false # Make sure our requests worked
            sessions.close_all
            EM.stop
          end
        end
      end
    end
  end
end
