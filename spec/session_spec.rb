require 'spec_helper'
  class MocClient < HotTub::Client
    def initialize(url,options={})   
    end
  
    def get
      sleep(0.05)
    end
  end

describe HotTub::Session do
  before(:each) do
    @url = "http://www.testurl123.com/"
    @tub = HotTub::Session.new(:client => MocClient.new(@url)) 
  end

  context 'default configuration' do
    it "should have @pool_size of 5" do
      @tub.instance_variable_get(:@options)[:size].should eql(5)
    end
      
    it "should have @pool_timeout of 0" do
      @tub.instance_variable_get(:@options)[:blocking_timeout].should eql(0.5)
    end
  end
        
  describe '#add_connection?' do
    it "should be true if @pool_data[:length] is less than desired pool size and 
    the pool is empty?"do
      @tub.instance_variable_set(:@pool_data,{:current_size => 1})
      @tub.send(:add?).should be_true 
    end
          
    it "should be false pool has reached pool_size" do
      @tub.instance_variable_set(:@pool_data,{:current_size => 5})
      @tub.instance_variable_set(:@pool,
        ["connection","connection","connection","connection","connection"])
      @tub.send(:add?).should be_false
    end
  end
        
  describe '#add_connection' do
    it "should add connections for supplied url"do
      @tub.send(:add)
      @tub.instance_variable_get(:@pool).should_not be_nil
    end
  end   
        
  describe '#fetch_connection' do
    it "should raise Timeout::Error if an available is not found in time"do
      @tub.stub(:pool).and_return([])
      lambda { @tub.fetch}.should raise_error(Timeout::Error)
    end
    
    it "should not raise Timeout::Error if an available is not found in time"do
      @tub.instance_variable_get(:@options)[:never_block] = true
      @tub.stub(:pool).and_return([])
      lambda { @tub.fetch}.should_not raise_error(Timeout::Error)
    end
    
    it "should return an instance of the driver" do
      @tub.fetch.should be_instance_of(MocClient)
    end
  end
  
  describe '#run' do
    it "should fetch a connection and run the supplied block" do
      @fetched = nil
      
      @tub.run do |connection|
        @fetched = connection.class.name
      end
      @fetched.should eql("MocClient")
    end
    
    it "should return the connection after use" do
      @tub.run do |connection|
        @connection = connection
        @fetched = @tub.instance_variable_get(:@pool).include?(connection)
      end
      @fetched.should be_false # not in pool because its doing work
      
      # returned to pool after work was done
      @tub.instance_variable_get(:@pool).include?(@connection).should be_true
    end
  end
  
  context 'thread safety' do
    it "should work" do
      threads = []
      20.times.each do
        threads << Thread.new do
          @tub.run{|connection| connection.get}
        end
      end
      
      sleep(0.5)
      
      threads.each do |t|
        t.join
      end
      
      @tub.instance_variable_get(:@pool).length.should eql(5)
    end
  end
end
