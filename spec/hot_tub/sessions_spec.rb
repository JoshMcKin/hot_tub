require 'spec_helper'
require 'hot_tub/sessions'
require 'uri'
require 'time'

describe HotTub::Sessions do

  describe '#stage' do
    let(:key) { "https://www.somewebsite.com" }

    let(:sessions) { HotTub::Sessions.new }

    it { expect(sessions.stage(key) { MocClient.new }).to be_nil }

    it "should lazy load pool" do
      sessions.stage(key) { MocClient.new }
      expect(sessions.fetch(key)).to be_a(HotTub::Pool)
    end
  end


  describe '#get_or_set' do

    context "with &default_client" do
      let(:key) { "https://www.somewebsite.com" }

      let(:sessions) do
        sns = HotTub::Sessions.new #{ MocClient.new }
        sns.default_client = lambda { |url| MocClient.new(url) }
        sns
      end

      it "should add a new pool for the key" do
        pool = sessions.get_or_set(key)
        expect(pool).to be_a(HotTub::Pool)
        pool.run do |clnt|
          expect(clnt).to be_a(MocClient)
        end
      end
    end

    context "with &client_block" do
      let(:key) { "https://www.somewebsite.com" }

      let(:sessions) { HotTub::Sessions.new }

      it "should add a new client for the key" do
        pool = sessions.get_or_set(key) { MocClient.new }
        expect(pool).to be_a(HotTub::Pool)
        pool.run do |clnt|
          expect(clnt).to be_a(MocClient)
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
      expect(sessions.reaper).to be_a(HotTub::Reaper)
    end

    it "should disable pool based reaper" do
      sessions.get_or_set("https://www.somewebsite.com") { MocClient.new }
      sessions.get_or_set("https://www.someOtherwebsite.com") { MocClient.new }
      sessions.get_or_set("https://www.someOtherwebsiteToo.com") { MocClient.new }
      session = sessions.instance_variable_get(:@_sessions)
      session.each_value {|v| expect(v.reaper).to eql(false)}
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
