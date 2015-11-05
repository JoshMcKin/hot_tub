require 'spec_helper'
require 'hot_tub/sessions'
require 'uri'
require 'time'
describe HotTub::Sessions do


  context 'initialized with a block' do

    let(:key) { "https://www.somewebsite.com" }

    let(:sessions) { HotTub::Sessions.new }

    describe '#sessions' do
      context 'HotTub::Pool as client' do
        it "should add a new client for the key" do
          sessions = HotTub::Sessions.new
          sessions.get_or_set(key) { MocClient.new } 
          sns = sessions.instance_variable_get(:@_sessions)
          expect(sns.size).to eql(1)
          sns.each_value {|v| expect(v).to be_a( HotTub::Pool)}
        end
      end
    end
  end

  describe '#reaper' do
    let(:url) { "https://www.somewebsite.com" }

    let(:sessions) { HotTub::Sessions.new }

    it "should start reaper after add" do
      expect(sessions.reaper).to be_nil
      sessions.get_or_set("https://www.somewebsite.com") { MocClient.new } 
      expect(sessions.reaper).to be_a(Thread)
    end

    it "should disable pool based reaper" do
      sessions.get_or_set("https://www.somewebsite.com") { MocClient.new } 
      sessions.get_or_set("https://www.someOtherwebsite.com") { MocClient.new } 
      sessions.get_or_set("https://www.someOtherwebsiteToo.com") { MocClient.new } 
      session = sessions.instance_variable_get(:@_sessions)
      session.each_value {|v| expect(v.reaper).to be_nil}
    end

  end

  describe '#run' do
    it "should pass run to pool" do
      url = HotTub::Server.url
      sessions = HotTub::Sessions.new
      sessions.get_or_set(url) do
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = false
        http.start
        http
      end
      result = nil
      sessions.run(url) do |conn|
        uri = URI.parse(url)
        result = conn.get(uri.path).code
      end
      expect(result).to eql('200')
    end
  end

  describe '#clean!' do
    it "should clean all pools in sessions" do
      sessions = HotTub::Sessions.new
      sessions.get_or_set('foo') { |url| MocClient.new(url) }
      sessions.get_or_set('bar') { |url| MocClient.new(url) }
      sessions.clean!
      sessions.instance_variable_get(:@_sessions).each_pair do |k,v|
        v.instance_variable_get(:@_pool).each do |c|
          expect(c).to be_cleaned
        end
      end
    end
  end

  describe '#drain!' do
    it "should drain all pools in sessions" do
      sessions = HotTub::Sessions.new
      sessions.get_or_set('foo') { |url| MocClient.new(url) }
      sessions.get_or_set('bar') { |url| MocClient.new(url) }
      sessions.drain!
      expect(sessions.instance_variable_get(:@_sessions)).to_not be_empty
    end
  end

  describe '#reap!' do
    it "should clean all pools in sessions" do
      sessions = HotTub::Sessions.new
      sessions.get_or_set('foo') { |url| MocClient.new(url) }
      sessions.get_or_set('bar') { |url| MocClient.new(url) }
      sessions.reap!
      sessions.instance_variable_get(:@_sessions).each_pair do |k,v|
        v.instance_variable_get(:@_pool).each do |c|
          expect(c).to be_reaped
        end
      end
    end
  end

  describe '#reset!' do
    it "should reset all pools in sessions" do
      sessions = HotTub::Sessions.new
      sessions.get_or_set('foo') { |url| MocClient.new(url) }
      sessions.get_or_set('bar') { |url| MocClient.new(url) }
      sessions.reset!
      sessions.instance_variable_get(:@_sessions).each_pair do |k,v|
        expect(v.instance_variable_get(:@_pool)).to be_empty
        expect(v.instance_variable_get(:@_out)).to be_empty
      end
    end
  end
end
