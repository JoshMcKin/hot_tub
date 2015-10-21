require 'spec_helper'
describe HotTub::Pool do

  context 'default settings' do
    let(:pool) { HotTub::Pool.new { MocClient.new } }

    it "should have :size of 5" do
      expect(pool.instance_variable_get(:@size)).to eql(5)
    end

    it "should have :wait_timeout of 0.5" do
      expect(pool.instance_variable_get(:@wait_timeout)).to eql(10)
    end

    it "should have set the client" do
      expect(pool.instance_variable_get(:@new_client).call).to be_a(MocClient)
    end

    it "should be true" do
      expect(pool.instance_variable_get(:@max_size)).to eql(0)
    end

    it "should have a HotTub::Reaper" do
      expect(pool.reaper).to be_a(Thread)
    end
  end

  context 'custom settings' do

    let(:pool) { HotTub::Pool.new(:size => 10, :wait_timeout => 1.0, :max_size => 20) { MocClient.new } }

    it { expect(pool.instance_variable_get(:@size)).to eql(10) }

    it { expect(pool.instance_variable_get(:@wait_timeout)).to eql(1.0) }

    it { expect(pool.instance_variable_get(:@max_size)).to eql(20) }
  end

  describe '#run' do
    let(:pool) { HotTub::Pool.new { MocClient.new} }

    it "should remove connection from pool when doing work" do
      pool.run do |connection|
        conn = connection
        expect(pool.instance_variable_get(:@pool).select{|c| c.object_id == conn.object_id}.length).to eql(0)
      end
    end

    it "should return the connection after use" do
      conn = nil
      pool.run do |connection|
        conn = connection
      end
      # returned to pool after work was done
      expect(pool.instance_variable_get(:@pool).pop).to eql(conn)
    end

    it "should work" do
      result = nil
      pool.run{|clnt| result = clnt.get}
      expect(result).to_not be_nil
    end

    context 'block not given' do
      it "should raise ArgumentError" do
        expect { pool.run }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#drain!' do
    let(:pool) { HotTub::Pool.new(:size => 5) { MocClient.new } }
    before(:each) do
      pool.instance_variable_set(:@out, [MocClient.new,MocClient.new,MocClient.new])
      pool.instance_variable_set(:@pool, [MocClient.new,MocClient.new,MocClient.new])
    end


    it "should reset pool" do
      pool.drain!
      expect(pool.instance_variable_get(:@pool).length).to eql(0)
      expect(pool.instance_variable_get(:@out).length).to eql(0)
    end
  end

  describe '#clean!' do
    let(:pool) { HotTub::Pool.new(:size => 3, :clean => lambda { |clnt| clnt.clean}) { MocClient.new } }

    it "should clean pool" do
      pool.instance_variable_set(:@pool, [MocClient.new,MocClient.new,MocClient.new])
      expect(pool.instance_variable_get(:@pool).first).to_not be_cleaned
      pool.clean!
      pool.instance_variable_get(:@pool).each do |clnt|
        expect(clnt).to be_cleaned
      end
    end
  end

  describe '#shutdown!' do
    let(:pool) { HotTub::Pool.new(:size => 5) { MocClient.new } }

    it "should kill reaper" do
      pool.shutdown!
      sleep(0.01)
      expect(pool.instance_variable_get(:@reaper).status).to eql(false)
    end

    it "should reset pool" do
      pool.instance_variable_set(:@pool, [MocClient.new,MocClient.new,MocClient.new])
      pool.shutdown!
      expect(pool.instance_variable_get(:@pool).length).to eql(0)
      expect(pool.send(:_total_current_size)).to eql(0)
    end
  end

  context 'private methods' do
    let(:pool) { HotTub::Pool.new { MocClient.new}  }

    describe '#client' do
      it "should raise HotTub::BlockingTimeout if an available is not found in time"do
        pool.instance_variable_set(:@non_blocking,false)
        pool.instance_variable_set(:@wait_timeout, 0.1)
        allow(pool).to receive(:raise_alarm?).and_return(true)
        expect { puts pool.send(:pop) }.to raise_error(HotTub::Pool::Timeout)
      end

      it "should return an instance of the client" do
        expect(pool.send(:client)).to be_instance_of(MocClient)
      end
    end

    describe '_fetch_new?' do
      it "should be true if @pool_data[:length] is less than desired pool size and the pool is empty?"do
        pool.instance_variable_set(:@pool,[])
        expect(pool.send(:_fetch_new?)).to eql(true)
      end

      it "should be false pool has reached pool_size" do
        pool.instance_variable_set(:@size, 5)
        pool.instance_variable_set(:@pool,[1,1,1,1,1])
        expect(pool.send(:_fetch_new?)).to eql(false)
      end
    end

    describe '#_fetch_new' do
      it "should add return a client"do
        pre_add_length = pool.instance_variable_get(:@pool).length
        expect(pool.send(:_fetch_new)).to_not be_nil
      end
    end

    describe '#push' do
      context "client is registered" do
        it "should push client back to pool" do
          pool.instance_variable_get(:@pool) << pool.send(:_fetch_new)
          clnt = pool.instance_variable_get(:@pool).pop
          pool.send(:push,clnt)
          expect(pool.instance_variable_get(:@pool).include?(clnt)).to eql(true)
        end
      end
      context "client is nil" do
        it "should not push client back to pool" do
          pool.send(:push,nil)
          expect(pool.instance_variable_get(:@pool).include?(nil)).to eql(false)
        end
      end
    end
  end

  context ':max_size' do
    context 'is default' do
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
        expect(pool.send(:_total_current_size)).to be > 1
      end
    end
    context 'is set' do
      it "should not add clients to pool beyond specified size" do
        pool = HotTub::Pool.new({:size => 1, :max_size => 1, :wait_timeout => 100}) { MocClient.new }
        threads = []
        5.times.each do
          threads << Thread.new do
            pool.run{|cltn| cltn.get }
          end
        end
        threads.each do |t|
          t.join
        end
        expect(pool.send(:_total_current_size)).to eql(1)
      end
    end
  end

  describe '#reap' do
    context 'current_size is greater than :size' do
      it "should remove a client from the pool" do
        pool = HotTub::Pool.new({:size => 1}) { MocClient.new }
        pool.instance_variable_set(:@last_activity,(Time.now - 601))
        pool.instance_variable_set(:@pool, [MocClient.new,MocClient.new,MocClient.new])
        expect(pool.send(:_reap?)).to eql(true)
        pool.reaper.wakeup # run the reaper thread
        sleep(0.01) # let results
        expect(pool.send(:_total_current_size)).to eql(1)
        expect(pool.instance_variable_get(:@pool).length).to eql(1)
      end
    end
  end

  context 'thread safety' do
    it "should work" do
      pool = HotTub::Pool.new({:size => 10}) { MocClient.new }
      failed = false
      expect {
        threads = []
        20.times.each do
          threads << Thread.new do
            pool.run{|connection| connection.get }
          end
        end
        threads.each do |t|
          t.join
        end
      }.to_not raise_error
      expect(pool.instance_variable_get(:@pool).length).to be >= 10
    end
  end

  context 'feature tests' do
    context "blocking (size equals max_size)" do
      let(:pool) do
        HotTub::Pool.new(:size => 5, :max_size => 5) {
          uri = URI.parse(HotTub::Server.url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = false
          http.start
          http
        }
      end

      it "should work" do
        result = nil
        pool.run{|clnt|
          uri = URI.parse(HotTub::Server.url)
          result = clnt.head(uri.path).code
        }
        expect(result).to eql('200')
      end
      context 'threads' do
        it "should work" do
          failed = false
          threads = []
          expect { net_http_thread_work(pool,10, threads) }.to_not raise_error
          pool.reap!
          expect { net_http_thread_work(pool,20, threads) }.to_not raise_error
          expect(pool.current_size).to eql(5) # make sure the pool grew beyond size
          results = threads.collect{ |t| t[:status]}
          expect(results.length).to eql(30) # make sure all threads are present
          expect(results.uniq).to eql(['200']) # make sure all returned status 200
        end
      end
    end

    context "with larger max" do
      let(:pool) do
        HotTub::Pool.new(:size => 5, :max_size => 10) {
          uri = URI.parse(HotTub::Server.url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = false
          http.start
          http
        }
      end
      it "should work" do
        result = nil
        pool.run{|clnt|
          uri = URI.parse(HotTub::Server.url)
          result = clnt.head(uri.path).code
        }
        expect(result).to eql('200')
      end
      context 'threads' do
        it "should work" do
          failed = false
          threads = []
          expect { net_http_thread_work(pool,10, threads) }.to_not raise_error
          expect { net_http_thread_work(pool,40, threads) }.to_not raise_error
          expect(pool.current_size).to eql(10)
          results = threads.collect{ |t| t[:status]}
          expect(results.length).to eql(50) # make sure all threads are present
          expect(results.uniq).to eql(['200']) # make sure all returned status 200
        end
      end
    end

    context "sized without max" do
      let(:pool) do
        HotTub::Pool.new(:size => 5) {
          uri = URI.parse(HotTub::Server.url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = false
          http.start
          http
        }
      end

      it "should work" do
        result = nil
        pool.run{|clnt|
          uri = URI.parse(HotTub::Server.url)
          result = clnt.head(uri.path).code
        }
        expect(result).to eql('200')
      end
      
      context 'threads' do
        it "should work" do
          failed = false
          threads = []
          expect { net_http_thread_work(pool,10, threads) }.to_not raise_error
          pool.reap! # Force reaping to shrink pool back
          expect { net_http_thread_work(pool,40, threads) }.to_not raise_error
          expect(pool.current_size).to be > 5 # make sure the pool grew beyond size
          results = threads.collect{ |t| t[:status]}
          expect(results.length).to eql(50) # make sure all threads are present
          expect(results.uniq).to eql(['200']) # make sure all returned status 200
        end
      end
    end
  end

  context 'Excon' do
    it "should work" do
      pool = HotTub::Pool.new(:size => 5, :max_size => 5) do
        Excon.new(HotTub::Server.url, :thread_safe_sockets => false)
      end
      failed = false
      threads = []
      expect { 50.times do
                 excon_thread_work(pool, 10, threads)
               end
               }.to_not raise_error
      results = threads.collect{ |t| t[:status]}
      expect(results.length).to eql(500) # make sure all threads are present
      expect(results.uniq).to eql([200]) # make sure all returned status 200
    end
  end

  def excon_thread_work(pool,thread_count=0, threads=[])
    thread_count.times.each do
      threads << Thread.new do
        uri = URI.parse(HotTub::Server.url)
        pool.run{|connection| Thread.current[:status] = connection.head(:path => uri.path).status }
      end
    end
    threads.each do |t|
      t.join
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
