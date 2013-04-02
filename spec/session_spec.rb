require 'spec_helper'
require 'hot_tub/session'
require 'uri'
describe HotTub::Session do

  it "should raise error if block is not supplied" do
    lambda {HotTub::Session.new}.should raise_error(ArgumentError)
  end

  context 'default settings' do
    before(:each) do
      @url = "http://www.testurl123.com/"
      @tub = HotTub::Session.new { |url| MocClient.new(url) }
      @options = @tub.instance_variable_get(:@options)
    end

    it "should have :size of 5" do
      @options[:size].should eql(5)
    end

    it "should have :blocking_timeout of 10 seconds" do
      @options[:blocking_timeout].should eql(10)
    end

    it "should default never_block to true" do
      @options[:never_block].should be_true
    end
  end

  context 'passed options' do
    before(:each) do
      @url = "http://www.testurl123.com/"
      @tub = HotTub::Session.new({:size => 21, :never_block => false}) { |url| MocClient.new(url) }
      @options = @tub.instance_variable_get(:@options)
    end

    it "should have @pool_size of 21" do
      @options[:size].should eql(21)
    end

    it "should have never_block be false" do
      @options[:never_block].should be_false
    end
  end

  describe '#sessions' do
    before(:each) do
      @url = "https://www.google.com"
      @uri = URI(@url)
      @tub = HotTub::Session.new({:size => 21, :never_block => false}) { |url| MocClient.new(url) }
    end
    
    it "should add a new pool for the url" do
      @tub.sessions(@url)
      sessions = @tub.instance_variable_get(:@sessions)
      sessions.length.should eql(1)
      sessions.first[1].should be_a(HotTub::Pool)
    end

    context "passed URL string" do
      it "should set key with URI scheme-domain" do
        @tub.sessions(@url)
        sessions = @tub.instance_variable_get(:@sessions)
        sessions["#{@uri.scheme}-#{@uri.host}"].should be_a(HotTub::Pool)
      end
    end

    context "passed URI" do
      it "should set key with URI scheme-domain" do
        @tub.sessions(@uri)
        sessions = @tub.instance_variable_get(:@sessions)
        sessions["#{@uri.scheme}-#{@uri.host}"].should be_a(HotTub::Pool)
      end
    end

    context "invalid argument" do
      it "should raise an ArgumentError" do
        lambda { @tub.sessions(nil) }.should raise_error(ArgumentError)

      end
      it  "should raise URI::InvalidURIError with bad url" do
        lambda { @tub.sessions("bad url") }.should raise_error(URI::InvalidURIError)
      end
    end
  end
  describe '#run' do
    it "should work" do
      @url = "https://www.google.com"
      @tub = HotTub::Session.new({:size => 21, :never_block => false}) { |url| HTTPClient.new }
      status = 0
      @tub.run(@url) do |conn|
        status =  conn.head(@url).status
      end
      status.should eql(200)
    end
  end

  context 'thread safety' do
    it "should work" do
      url = "https://www.google.com/"
      url2 = "https://www.yahoo.com/"
      session = HotTub::Session.new({:size => 20}) { |a_url| HTTPClient.new}
      failed = false
      lambda {
        threads = []
        20.times.each do
          threads << Thread.new do
            session.run(url){|connection| failed = true unless connection.head(url).status == 200}
            session.run(url2){|connection| failed = true unless connection.head(url).status == 200}
          end
        end
        sleep(0.01)
        threads.each do |t|
          t.join
        end
      }.should_not raise_error
      session.instance_variable_get(:@sessions).keys.length.should eql(2) # make sure work got done
      session.instance_variable_get(:@sessions).values.first.instance_variable_get(:@pool).length.should eql(20) # make sure work got done
      session.instance_variable_get(:@sessions).values.last.instance_variable_get(:@pool).length.should eql(20) # make sure work got done
      failed.should be_false # Make sure our requests woked
    end
  end
end
