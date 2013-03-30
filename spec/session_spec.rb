require 'spec_helper'
require 'hot_tub/session'
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
end
