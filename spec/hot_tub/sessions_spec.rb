require 'spec_helper'
require 'hot_tub/sessions'
require 'uri'
require 'time'
describe HotTub::Sessions do

  context 'initialized without a block' do
    it "should raise error if block is not supplied" do
      expect { HotTub::Sessions.new }.to raise_error(ArgumentError)
    end
  end

  context 'initialized with a block' do

    let(:url) { "https://www.somewebsite.com" }
    let(:uri) { URI(url) }

    let(:sessions) { HotTub::Sessions.new { |url| MocClient.new(url) } }


    describe '#to_url' do
      context "passed URL string" do
        it "should return key with URI scheme-domain" do
          expect(sessions.send(:to_key,url)).to eql("#{uri.scheme}://#{uri.host}:#{uri.port}")
        end
      end

      context "passed URI" do
        it "should return key with URI scheme-domain" do
          expect(sessions.send(:to_key,uri)).to eql("#{uri.scheme}://#{uri.host}:#{uri.port}")
        end
      end

      context "invalid argument" do
        it "should raise an ArgumentError" do
          expect { sessions.send(:to_key, nil) }.to raise_error(ArgumentError)
        end
        it  "should raise URI::InvalidURIError with bad url" do
          expect { sessions.send(:to_key,"bad url") }.to raise_error(URI::InvalidURIError)
        end
      end
    end

    describe '#sessions' do
      context 'HotTub::Pool as client' do
        it "should add a new client for the url" do
          with_pool_options = HotTub::Sessions.new { |url| HotTub::Pool.new(:size => 13) { MocClient.new(url) } }
          with_pool_options.sessions(url)
          sessions = with_pool_options.instance_variable_get(:@sessions)
          expect(sessions.size).to eql(1)
          sessions.each_value {|v| expect(v).to be_a( HotTub::Pool)}
        end
      end

      context 'other clients' do
        it "should add a new client for the url" do
          no_pool = HotTub::Sessions.new { |url| Excon.new(url) }
          no_pool.sessions(url)
          sns = no_pool.instance_variable_get(:@sessions)
          expect(sns.size).to eql(1)
          sns.each_value {|v| expect(v).to be_a(Excon::Connection)}
        end
      end

      context "passed URL string" do
        it "should set key with URI scheme-domain" do
          sessions.sessions(url)
          sns = sessions.instance_variable_get(:@sessions)
          expect(sns["#{uri.scheme}://#{uri.host}:#{uri.port}"]).to be_a(MocClient)
        end
      end
      context "passed URI" do
        it "should set key with URI scheme-domain" do
          sessions.sessions(uri)
          sns = sessions.instance_variable_get(:@sessions)
          expect(sns["#{uri.scheme}://#{uri.host}:#{uri.port}"]).to be_a(MocClient)
        end
      end

      context "with_pool" do
        it "should initialize a new HotTub::Pool" do
          session_with_pool = HotTub::Sessions.new({:with_pool => true})  { |url| MocClient.new(url) }
          pool = session_with_pool.sessions(url)
          expect(pool).to be_a(HotTub::Pool)
        end
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
      expect(result).to eql(200)
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
        expect(result).to eql('200')
      end
    end
  end

  describe '#clean!' do
    it "should clean all sessions" do
      sessions = HotTub::Sessions.new(:clean => lambda { |clnt| clnt.clean}) { |url| MocClient.new(url) }
      sessions.sessions('foo')
      sessions.sessions('bar')
      sessions.clean!
      sessions.instance_variable_get(:@sessions).each_pair do |k,v|
        expect(v).to be_cleaned
      end
    end
    context "with_pool" do
      it "should clean all pools in sessions" do
        sessions = HotTub::Sessions.new(:with_pool => true, :clean => lambda { |clnt| clnt.clean}) { |url| MocClient.new(url) }
        sessions.sessions('foo')
        sessions.sessions('bar')
        sessions.clean!
        sessions.instance_variable_get(:@sessions).each_pair do |k,v|
          v.instance_variable_get(:@pool).each do |c|
            expect(c).to be_cleaned
          end
        end
      end
    end
  end

  describe '#drain!' do
    it "should drain all sessions" do
      sessions = HotTub::Sessions.new { |url| MocClient.new(url) }
      sessions.sessions('foo')
      sessions.sessions('bar')
      sessions.drain!
      expect(sessions.instance_variable_get(:@sessions)).to be_empty
    end
    context "with_pool" do
      it "should drain all pools in sessions" do
        sessions = HotTub::Sessions.new(:with_pool => true) { |url| MocClient.new(url) }
        sessions.sessions('foo')
        sessions.sessions('bar')
        sessions.drain!
        expect(sessions.instance_variable_get(:@sessions)).to be_empty
      end
    end
  end

  describe '#reap!' do
    it "should clean all sessions" do
      sessions = HotTub::Sessions.new(:reap => lambda { |clnt| clnt.reap}) { |url| MocClient.new(url) }
      sessions.sessions('foo')
      sessions.sessions('bar')
      sessions.reap!
      sessions.instance_variable_get(:@sessions).each_pair do |k,v|
        expect(v).to be_reaped
      end
    end
    context "with_pool" do
      it "should clean all pools in sessions" do
        sessions = HotTub::Sessions.new(:with_pool => true, :reap => lambda { |clnt| clnt.reap}) { |url| MocClient.new(url) }
        sessions.sessions('foo')
        sessions.sessions('bar')
        sessions.reap!
        sessions.instance_variable_get(:@sessions).each_pair do |k,v|
          v.instance_variable_get(:@pool).each do |c|
            expect(c).to be_reaped
          end
        end
      end
    end
  end
  context 'integration tests' do
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
        expect {
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
        }.to_not raise_error # make sure we're thread safe
        # Some extra checks just to make sure...
        results = threads.collect{ |t| t[:result]}
        expect(results.length).to eql(10) # make sure all threads are present
        expect(results.uniq).to eql([results.first]) # make sure we got the same results
        expect(session.instance_variable_get(:@sessions).keys.length).to eql(2) # make sure sessions were created
      end
    end
  end
end
