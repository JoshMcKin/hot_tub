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
      context "passed URL string" do
        it "should set key with URI scheme-domain" do
          sessions.sessions(url)
          sns = sessions.instance_variable_get(:@sessions)
          expect(sns["#{uri.scheme}://#{uri.host}:#{uri.port}"]).to be_a(HotTub::Pool)
        end
      end
      context "passed URI" do
        it "should set key with URI scheme-domain" do
          sessions.sessions(uri)
          sns = sessions.instance_variable_get(:@sessions)
          expect(sns["#{uri.scheme}://#{uri.host}:#{uri.port}"]).to be_a(HotTub::Pool)
        end
      end
    end
  end

  describe '#run' do
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

  describe '#clean!' do
    it "should clean all pools in sessions" do
      sessions = HotTub::Sessions.new(:with_pool => true, :clean => lambda { |clnt| clnt.clean}) { |url| MocClient.new(url) }
      sessions.sessions('foo')
      sessions.sessions('bar')
      sessions.clean!
      sessions.instance_variable_get(:@sessions).each_pair do |k,v|
        v.instance_variable_get(:@_pool).each do |c|
          expect(c).to be_cleaned
        end
      end
    end
  end

  describe '#drain!' do
    it "should drain all pools in sessions" do
      sessions = HotTub::Sessions.new(:with_pool => true) { |url| MocClient.new(url) }
      sessions.sessions('foo')
      sessions.sessions('bar')
      sessions.drain!
      expect(sessions.instance_variable_get(:@sessions)).to_not be_empty
    end
  end

  describe '#reap!' do
    it "should clean all pools in sessions" do
      sessions = HotTub::Sessions.new(:with_pool => true, :reap => lambda { |clnt| clnt.reap}) { |url| MocClient.new(url) }
      sessions.sessions('foo')
      sessions.sessions('bar')
      sessions.reap!
      sessions.instance_variable_get(:@sessions).each_pair do |k,v|
        v.instance_variable_get(:@_pool).each do |c|
          expect(c).to be_reaped
        end
      end
    end
  end

  describe '#reset!' do
    it "should reset all pools in sessions" do
      sessions = HotTub::Sessions.new(:with_pool => true) { |url| MocClient.new(url) }
      sessions.sessions('foo')
      sessions.sessions('bar')
      sessions.reset!
      expect(sessions.instance_variable_get(:@sessions)).to be_empty
    end
  end
end
