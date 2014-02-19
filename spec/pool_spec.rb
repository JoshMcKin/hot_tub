require 'spec_helper'
describe HotTub::Pool do

  context 'default settings' do
    before(:each) do
      @pool = HotTub::Pool.new { MocClient.new }
    end

    it "should have :size of 5" do
      @pool.instance_variable_get(:@size).should eql(5)
    end

    it "should have :blocking_timeout of 0.5" do
      @pool.instance_variable_get(:@blocking_timeout).should eql(10)
    end

    it "should have set the client" do
      @pool.instance_variable_get(:@new_client).call.should be_a(MocClient)
    end

    it "should be true" do
      @pool.instance_variable_get(:@non_blocking).should be_true
    end

    it "should have a HotTub::Reaper" do
      @pool.reaper.should be_a(HotTub::Reaper)
    end
  end

  context 'custom settings' do
    before(:each) do
      @pool = HotTub::Pool.new(:size => 10, :blocking_timeout => 1.0, :non_blocking => false) { MocClient.new }
    end

    it "should have :size of 5" do
      @pool.instance_variable_get(:@size).should eql(10)
    end

    it "should have :blocking_timeout of 0.5" do
      @pool.instance_variable_get(:@blocking_timeout).should eql(1.0)
    end

    it "should be true" do
      @pool.instance_variable_get(:@non_blocking).should be_false
    end
  end

  describe '#run' do
    before(:each) do
      @pool = HotTub::Pool.new { MocClient.new}
    end

    it "should remove connection from pool when doing work" do
      @pool.run do |connection|
        @connection = connection
        @fetched = @pool.instance_variable_get(:@pool).select{|c| c.object_id == @connection.object_id}.length.should eql(0) # not in pool because its doing work
      end
    end

    it "should return the connection after use" do
      @connection = nil
      @pool.run do |connection|
        @connection = connection
      end
      # returned to pool after work was done
      @pool.instance_variable_get(:@pool).pop.should eql(@connection)
    end

    it "should work" do
      result = nil
      @pool.run{|clnt| result = clnt.get}
      result.should_not be_nil
    end

    context 'block not given' do
      it "should raise ArgumentError" do
        lambda { @pool.run }.should raise_error(ArgumentError)
      end
    end
  end

  describe '#drain!' do
    before(:each) do
      @pool = HotTub::Pool.new(:size => 5) { MocClient.new }
      @pool.instance_variable_set(:@out, [MocClient.new,MocClient.new,MocClient.new])
      @pool.instance_variable_set(:@pool, [MocClient.new,MocClient.new,MocClient.new])
    end

    context ":close_out" do
      it "should reset out" do
        @pool.instance_variable_set(:@close_out, true)
        @pool.drain!
        @pool.instance_variable_get(:@out).length.should eql(0)
      end
    end

    it "should reset pool" do
      @pool.drain!
      @pool.instance_variable_get(:@pool).length.should eql(0)
      @pool.send(:_total_count).should eql(3)
      @pool.instance_variable_get(:@out).length.should eql(3)
    end
  end

  describe '#clean!' do
    before(:each) do
      @pool = HotTub::Pool.new(:size => 3, :clean => lambda { |clnt| clnt.clean}) { MocClient.new }
    end

    it "should clean pool" do
      @pool.instance_variable_set(:@pool, [MocClient.new,MocClient.new,MocClient.new])
      @pool.instance_variable_get(:@pool).first.cleaned?.should be_false
      @pool.clean!
      @pool.instance_variable_get(:@pool).each do |clnt|
        clnt.cleaned?.should be_true
      end
    end
  end

  describe '#shutdown!' do
    before(:each) do
      @pool = HotTub::Pool.new(:size => 5) { MocClient.new }
    end

    it "should kill reaper" do
      @pool.shutdown!
      sleep(0.01)
      @pool.instance_variable_get(:@reaper).status.should be_false
    end

    it "should reset pool" do
      @pool.instance_variable_set(:@pool, [MocClient.new,MocClient.new,MocClient.new])
      @pool.shutdown!
      @pool.instance_variable_get(:@pool).length.should eql(0)
      @pool.send(:_total_count).should eql(0)
    end
  end

  context 'private methods' do
    before(:each) do
      @url = "http://www.testurl123.com/"
      @pool = HotTub::Pool.new { MocClient.new}
    end

    describe '#client' do
      it "should raise HotTub::BlockingTimeout if an available is not found in time"do
        @pool.instance_variable_set(:@non_blocking,false)
        @pool.instance_variable_set(:@blocking_timeout, 0.1)
        @pool.stub(:raise_alarm?).and_return(true)
        lambda { puts @pool.send(:pop) }.should raise_error(HotTub::BlockingTimeout)
      end

      it "should return an instance of the client" do
        @pool.send(:client).should be_instance_of(MocClient)
      end
    end

    describe 'add?' do
      it "should be true if @pool_data[:length] is less than desired pool size and
    the pool is empty?"do
        @pool.instance_variable_set(:@pool,[])
        @pool.send(:_add?).should be_true
      end

      it "should be false pool has reached pool_size" do
        @pool.instance_variable_set(:@size, 5)
        @pool.instance_variable_set(:@pool,[1,1,1,1,1])
        @pool.send(:_add?).should be_false
      end
    end

    describe '#_add' do
      it "should add client for supplied url"do
        pre_add_length = @pool.instance_variable_get(:@pool).length
        @pool.send(:_add)
        @pool.instance_variable_get(:@pool).length.should be > pre_add_length
      end
    end

    describe '#push' do
      context "client is registered" do
        it "should push client back to pool" do
          @pool.send(:_add)
          clnt = @pool.instance_variable_get(:@pool).pop
          @pool.send(:push,clnt)
          @pool.instance_variable_get(:@pool).include?(clnt).should be_true
        end
      end
      context "client is nil" do
        it "should not push client back to pool" do
          @pool.send(:push,nil)
          @pool.instance_variable_get(:@pool).include?(nil).should be_false
        end
      end
    end
  end

  context ':non_blocking' do
    context 'is true' do
      it "should add clients to pool as necessary" do
        pool = HotTub::Pool.new({:size => 1}) { MocClient.new }
        threads = []
        5.times.each do
          threads << Thread.new do
            pool.run{|cltn| cltn.get }
          end
        end
        threads.each do |t|
          t.join
        end
        (pool.send(:_total_count) > 1).should be_true
      end
    end
    context 'is false' do
      it "should not add clients to pool beyond specified size" do
        pool = HotTub::Pool.new({:size => 1, :non_blocking => false, :blocking_timeout => 100}) { MocClient.new }
        threads = []
        5.times.each do
          threads << Thread.new do
            pool.run{|cltn| cltn.get }
          end
        end
        threads.each do |t|
          t.join
        end
        pool.send(:_total_count).should eql(1)
      end
    end
  end

  describe '#reap' do
    context 'current_size is greater than :size' do
      it "should remove a client from the pool" do
        pool = HotTub::Pool.new({:size => 1}) { MocClient.new }
        pool.instance_variable_set(:@last_activity,(Time.now - 601))
        pool.instance_variable_set(:@pool, [MocClient.new,MocClient.new,MocClient.new])
        pool.send(:_reap?).should be_true
        pool.reaper.wakeup # run the reaper thread
        sleep(0.1) # let results
        pool.send(:_total_count).should eql(1)
        pool.instance_variable_get(:@pool).length.should eql(1)
      end
    end
  end

  context 'thread safety' do
    it "should work" do
      pool = HotTub::Pool.new({:size => 10}) { MocClient.new }
      failed = false
      lambda {
        threads = []
        20.times.each do
          threads << Thread.new do
            pool.run{|connection| connection.get }
          end
        end
        threads.each do |t|
          t.join
        end
      }.should_not raise_error
      (pool.instance_variable_get(:@pool).length >= 10).should be_true # make sure work got done
    end
  end

  context "other http client" do
    before(:each) do
      @pool = HotTub::Pool.new(:clean => lambda {|clnt| clnt.clean}) {MocClient.new}
    end

    it "should clean connections" do
      @pool.run  do |clnt|
        clnt.cleaned?.should be_true
      end
    end
  end

  context 'integration tests' do
    context "blocking" do
      before(:each) do
        @pool = HotTub::Pool.new(:size => 5, :non_blocking => false) {
          uri = URI.parse(HotTub::Server.url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = false
          http.start
          http
        }
      end
      it "should work" do
        result = nil
        @pool.run{|clnt|
          uri = URI.parse(HotTub::Server.url)
          result = clnt.head(uri.path).code
        }
        result.should eql('200')
      end
      context 'threads' do
        it "should work" do
          failed = false
          threads = []
          lambda { net_http_thread_work(@pool,10, threads) }.should_not raise_error
          @pool.reap!
          lambda { net_http_thread_work(@pool,20, threads) }.should_not raise_error
          @pool.send(:_total_count).should  eql(5) # make sure the pool grew beyond size 
          results = threads.collect{ |t| t[:status]}
          results.length.should eql(30) # make sure all threads are present
          results.uniq.should eql(['200']) # make sure all returned status 200
        end
      end
    end
    context "never block without max" do
      before(:each) do
        @pool = HotTub::Pool.new(:size => 5) {
          uri = URI.parse(HotTub::Server.url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = false
          http.start
          http
        }
      end
      it "should work" do
        result = nil
        @pool.run{|clnt|
          uri = URI.parse(HotTub::Server.url)
          result = clnt.head(uri.path).code
        }
        result.should eql('200')
      end
      context 'threads' do
        it "should work" do
          failed = false
          threads = []
          lambda { net_http_thread_work(@pool,10, threads) }.should_not raise_error
          @pool.reap! # Force reaping to shrink pool back
          lambda { net_http_thread_work(@pool,20, threads) }.should_not raise_error
          @pool.send(:_total_count).should  > 5 # make sure the pool grew beyond size 
          results = threads.collect{ |t| t[:status]}
          results.length.should eql(30) # make sure all threads are present
          results.uniq.should eql(['200']) # make sure all returned status 200
        end
      end
    end
    context "never block with max" do
      before(:each) do
        @pool = HotTub::Pool.new(:size => 5, :max_size => 10) {
          uri = URI.parse(HotTub::Server.url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = false
          http.start
          http
        }
      end
      it "should work" do
        result = nil
        @pool.run{|clnt|
          uri = URI.parse(HotTub::Server.url)
          result = clnt.head(uri.path).code
        }
        result.should eql('200')
      end
      context 'threads' do
        it "should work" do
          failed = false
          threads = []
          lambda { net_http_thread_work(@pool,10, threads) }.should_not raise_error
          lambda { net_http_thread_work(@pool,20, threads) }.should_not raise_error
          @pool.send(:_total_count).should  > 5 # make sure pool is at max_size
          results = threads.collect{ |t| t[:status]}
          results.length.should eql(30) # make sure all threads are present
          results.uniq.should eql(['200']) # make sure all returned status 200
        end
      end
    end
  end

  def net_http_thread_work(pool,thread_count=0, threads=[])
    thread_count.times.each do
      threads << Thread.new do
        uri = URI.parse(HotTub::Server.url)
        pool.run{|connection| Thread.current[:status] = connection.head(uri.path).code }
      end
    end
    threads.each do |t|
      t.join
    end
  end
end
