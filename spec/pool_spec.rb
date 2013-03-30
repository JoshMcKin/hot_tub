require 'spec_helper'
unless HotTub.jruby?
  require "em-synchrony"
  require "em-synchrony/em-http"
end
describe HotTub::Pool do

  context 'default settings' do
    before(:each) do
      @pool = HotTub::Pool.new()
    end

    it "should have :size of 5" do
      @pool.instance_variable_get(:@size).should eql(5)
    end

    it "should have :blocking_timeout of 0.5" do
      @pool.instance_variable_get(:@blocking_timeout).should eql(10)
    end

    it "should have default :client" do
      @pool.instance_variable_get(:@client_block).call.should be_a(HTTPClient)
    end

    it "should be true" do
      @pool.instance_variable_get(:@never_block).should be_true
    end
  end

  context 'custom settings' do
    before(:each) do
      @pool = HotTub::Pool.new(:size => 10, :blocking_timeout => 1.0, :never_block => false) { MocClient.new }
    end

    it "should have :size of 5" do
      @pool.instance_variable_get(:@size).should eql(10)
    end

    it "should have :blocking_timeout of 0.5" do
      @pool.instance_variable_get(:@blocking_timeout).should eql(1.0)
    end

    it "should have defult :client" do
      @pool.instance_variable_get(:@client_block).call.should be_a(MocClient)
    end

    it "should be true" do
      @pool.instance_variable_get(:@never_block).should be_false
    end
  end

  describe '#run' do
    before(:each) do
      @pool = HotTub::Pool.new
    end

    it "should remove connection from pool when doing work" do
      @pool.run do |connection|
        @connection = connection
        @fetched = @pool.instance_variable_get(:@pool).select{|c| c.object_id == @connection.object_id}.length.should eql(0) # not in pool because its doing work
      end
    end

    it "should return the connection after use" do
      @pool.run do |connection|
        @connection = connection
      end
      # returned to pool after work was done
      @pool.instance_variable_get(:@pool).select{|c| c.object_id == @connection.object_id}.length.should eql(1)
    end

    it "should work" do
      @pool.run{|clnt| clnt.get('https://www.google.com')}
    end

    context "block given" do
      it "should call the supplied block" do
        status = nil
        @pool.run { |con| status = con.get('https://google.com').status}
        status.should_not be_nil
      end
    end

    context 'block not given' do
      it "should raise ArgumentError" do
        lambda { @pool.run }.should raise_error(ArgumentError)
      end
    end
  end

  describe '#close_all' do
    before(:each) do
      @pool = HotTub::Pool.new(:size => 5)
      5.times do
        @pool.send(:add)
      end
    end
    it "should reset pool" do
      @pool.current_size.should eql(5)
      @pool.instance_variable_get(:@clients).length.should eql(5)
      @pool.instance_variable_get(:@pool).length.should eql(5)
      @pool.close_all
      @pool.instance_variable_get(:@clients).length.should eql(0)
      @pool.instance_variable_get(:@pool).length.should eql(0)
      @pool.current_size.should eql(0)
    end
  end

  context 'private methods' do
    before(:each) do
      @url = "http://www.testurl123.com/"
      @pool = HotTub::Pool.new()
    end

    describe '#client' do
      it "should raise HotTub::BlockingTimeout if an available is not found in time"do
        @pool.instance_variable_set(:@never_block,false)
        @pool.instance_variable_set(:@blocking_timeout,0.1)
        @pool.stub(:pop).and_return(nil)
        lambda { puts @pool.send(:client) }.should raise_error(HotTub::BlockingTimeout)
      end

      it "should return an instance of the driver" do
        @pool.send(:client).should be_instance_of(HTTPClient)
      end
    end

    describe 'add?' do
      it "should be true if @pool_data[:length] is less than desired pool size and
    the pool is empty?"do
        @pool.instance_variable_set(:@pool,[])
        @pool.send(:add?).should be_true
      end

      it "should be false pool has reached pool_size" do
        @pool.instance_variable_set(:@pool_data,{:current_size => 5})
        @pool.instance_variable_set(:@pool,["connection","connection","connection","connection","connection"])
        @pool.send(:add?).should be_false
      end
    end

    describe '#add' do
      it "should add connections for supplied url"do
        @pool.send(:add)
        @pool.instance_variable_get(:@pool).should_not be_nil
      end
    end
  end

  context 'thread safety' do
    it "should work" do
      url = "https://www.google.com/"
      pool = HotTub::Pool.new({:size => 20})
      failed = false
      lambda {
        threads = []
        20.times.each do
          threads << Thread.new do
            pool.run{|connection| failed = true unless connection.head(url).status == 200}
          end
        end
        sleep(0.01)
        threads.each do |t|
          t.join
        end
      }.should_not raise_error
      pool.instance_variable_get(:@pool).length.should eql(20) # make sure work got done
      failed.should be_false # Make sure our requests woked
    end
  end

  context "other http client" do
    before(:each) do
      @url = "https://www.google.com"
      @pool = HotTub::Pool.new(:clean => lambda {|clnt| clnt.clean}) {MocClient.new(@url)}
    end

    it "should clean connections" do
      @pool.run  do |clnt|
        clnt.cleaned?.should be_true
      end
    end
  end

  unless HotTub.jruby?
    context 'EM:HTTPRequest' do
      before(:each) do
        @url = "https://www.google.com"
      end

      it "should work" do
        EM.synchrony do
          status = []
          c = HotTub::Pool.new {EM::HttpRequest.new(@url)}
          c.run { |conn| status << conn.head(:keepalive => true).response_header.status}
          c.run { |conn| status << conn.ahead(:keepalive => true).response_header.status}
          c.run { |conn| status << conn.head(:keepalive => true).response_header.status}
          status.should eql([200,0,200])
          EM.stop
        end
      end

      context 'fibers' do
        it "should work" do
          EM.synchrony do
            url = "https://www.google.com/"
            pool = HotTub::Pool.new({:size => 5}) {EM::HttpRequest.new(@url)}
            failed = false
            fibers = []
            lambda {
              10.times.each do
                fibers << Fiber.new do
                  pool.run{|connection| failed = true unless connection.head(:keepalive => true).response_header.status == 200}
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
            pool.instance_variable_get(:@pool).length.should eql(5) #make sure work got done
            failed.should be_false # Make sure our requests worked
            EM.stop
          end
        end
      end
    end
  end
end
