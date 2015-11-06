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
      expect(pool.instance_variable_get(:@client_block).call).to be_a(MocClient)
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
        expect(pool.instance_variable_get(:@_pool).select{|c| c.object_id == conn.object_id}.length).to eql(0)
      end
    end

    it "should return the connection after use" do
      conn = nil
      pool.run do |connection|
        conn = connection
      end
      # returned to pool after work was done
      expect(pool.instance_variable_get(:@_pool).pop).to eql(conn)
    end

    it "should work" do
      result = nil
      pool.run{|clnt| result = clnt.get}
      expect(result).to_not be_nil
    end

  end

  describe ':max_size option' do

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

  describe '#drain!' do
    let(:pool) { HotTub::Pool.new(:size => 4) { MocClient.new } }
    before(:each) do
      pool.instance_variable_set(:@_out, [MocClient.new,MocClient.new,MocClient.new])
      pool.instance_variable_set(:@_pool, [MocClient.new,MocClient.new,MocClient.new])
    end


    it "should drain pool" do
      pool.drain!
      expect(pool.instance_variable_get(:@_pool).length).to eql(0)
      expect(pool.instance_variable_get(:@_out).length).to eql(0)
    end
  end

  describe '#reset!' do
    let(:pool) { HotTub::Pool.new(:size => 4, :close => :close) { MocClient.new } }
    let(:client) { MocClient.new }

    before(:each) do
      pool.instance_variable_set(:@_out, [MocClient.new,MocClient.new])
      pool.instance_variable_set(:@_pool, [client,MocClient.new,MocClient.new])
    end

    it "should reset pool" do
      pool.reset!
      expect(client).to be_closed
      expect(pool.instance_variable_get(:@_pool).length).to eql(0)
      expect(pool.instance_variable_get(:@_out).length).to eql(0)
    end
  end

  describe '#clean!' do
    let(:pool) { HotTub::Pool.new(:size => 3, :clean => lambda { |clnt| clnt.clean}) { MocClient.new } }

    it "should clean pool" do
      pool.instance_variable_set(:@_pool, [MocClient.new,MocClient.new,MocClient.new])
      expect(pool.instance_variable_get(:@_pool).first).to_not be_cleaned
      pool.clean!
      pool.instance_variable_get(:@_pool).each do |clnt|
        expect(clnt).to be_cleaned
      end
    end
  end

  describe '#shutdown!' do
    let(:pool) { HotTub::Pool.new(:size => 4) { MocClient.new } }

    it "should kill reaper" do
      pool.shutdown!
      expect(pool.instance_variable_get(:@reaper)).to be_nil
    end

    it "should shutdown pool" do
      pool.instance_variable_set(:@_pool, [MocClient.new,MocClient.new,MocClient.new])
      pool.shutdown!
      expect(pool.instance_variable_get(:@_pool).length).to eql(0)
      expect(pool.send(:_total_current_size)).to eql(0)
    end
  end

  describe '#reap!' do
    it "should clients from the pool" do
      pool = HotTub::Pool.new({ :size => 1, :close => :close }) { MocClient.new }
      old_client = MocClient.new
      pool.instance_variable_set(:@last_activity,(Time.now - 601))
      pool.instance_variable_set(:@_pool, [old_client, MocClient.new, MocClient.new])
      pool.reap!
      expect(pool.current_size).to eql(1)
      expect(old_client).to be_closed
    end
  end

  context 'private methods' do
    let(:pool) { HotTub::Pool.new(:close => :close) { MocClient.new}  }

    describe '#pop' do
      context "is allowed" do
        it "should work" do
          expect(pool.send(:pop)).to be_a(MocClient)
        end
      end
    end

    describe '#push' do
      context "client is registered" do
        it "should push client back to pool" do
          clnt = pool.send(:pop)
          pool.send(:push,clnt)
          expect(pool.instance_variable_get(:@_pool).include?(clnt)).to eql(true)
        end
      end
      context "client is not registered" do
        it "should push client back to pool" do
          clnt = MocClient.new
          pool.send(:push,clnt)
          expect(pool.instance_variable_get(:@_pool).include?(clnt)).to eql(false)
          expect(clnt).to be_closed
        end
      end
      context "client is nil" do
        it "should not push client back to pool" do
          pool.send(:push,nil)
          expect(pool.instance_variable_get(:@_pool).include?(nil)).to eql(false)
        end
      end
    end
  end

  context 'thread safety' do
    it "should grow" do
      pool = HotTub::Pool.new({:size => 4}) { MocClient.new }
      failed = false
      threads = []
      20.times.each do
        threads << Thread.new do
          pool.run{|connection| connection.get }
        end
      end
      sleep(0.01)
      threads.each do |t|
        t.join
      end
      expect(pool.current_size).to be >= 4
    end
  end
end
