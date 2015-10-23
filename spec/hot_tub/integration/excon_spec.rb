require 'spec_helper'

describe HotTub do

  context "blocking (size equals max_size)" do
    let(:pool) do
      HotTub.new(:size => 4, :max_size => 4) {
        Excon.new(HotTub::Server.url, :thread_safe_sockets => false)
      }
    end

    let(:threads) { [] }

    before(:each) do
      5.times do
        excon_thread_work(pool, 30, threads)
      end
    end

    it { expect(pool.current_size).to eql(4) }# make sure the pool grew beyond size

    it "should work" do
      results = threads.collect{ |t| t[:status]}
      expect(results.length).to eql(150) # make sure all threads are present
      expect(results.uniq).to eql([200]) # make sure all returned status 200
    end

    it "should shutdown" do
      pool.shutdown!
      expect(pool.current_size).to eql(0)
    end
  end

  context "with larger max" do
    let(:pool) do
      HotTub.new(:size => 4, :max_size => 8) {
        Excon.new(HotTub::Server.url, :thread_safe_sockets => false)
      }
    end

    let(:threads) { [] }

    before(:each) do
      5.times do
        excon_thread_work(pool, 30, threads)
      end
    end

    it { expect(pool.current_size).to be >= 4 }

    it { expect(pool.current_size).to be <= 8 }

    it "should reap" do
      pool.reap!
      expect(pool.current_size).to eql(4)
    end

    it "should work" do
      results = threads.collect{ |t| t[:status]}
      expect(results.length).to eql(150) # make sure all threads are present
      expect(results.uniq).to eql([200]) # make sure all returned status 200
    end
  end

  context "sized without max" do
    let(:pool) do
      HotTub.new(:size => 4) {
        Excon.new(HotTub::Server.url, :thread_safe_sockets => false)
      }
    end

    let(:threads) { [] }

    before(:each) do
      5.times do
        excon_thread_work(pool, 30, threads)
      end
    end

    it { expect(pool.current_size).to be > 4 }# make sure the pool grew beyond size

    it "should reap" do
      pool.reap!
      expect(pool.current_size).to eql(4)
    end

    it "should work" do
      results = threads.collect{ |t| t[:status]}
      expect(results.length).to eql(150) # make sure all threads are present
      expect(results.uniq).to eql([200]) # make sure all returned status 200
    end
  end

  context "shutdown with slow client" do
    let(:pool) do
      HotTub.new(:size => 1) {
        Excon.new(HotTub::Server.slow_url, :thread_safe_sockets => false, :read_timeout => 10)
      }
    end

    it "should work" do
      conn = nil

      expect {
        th = Thread.new do
          uri = URI.parse(HotTub::Server.slow_url)
          pool.run do |connection|
            conn = connection
            connection.get(:path => uri.path).status
          end
        end
        sleep(0.01)
        pool.shutdown!
        th.join
      }.to raise_error(Excon::Errors::SocketError)

      expect(pool.shutdown).to eql(true)
      expect(pool.current_size).to eql(0)
      expect(conn.send(:sockets)).to be_empty
    end
  end

end



def excon_thread_work(pool,thread_count=0, threads=[])
  thread_count.times.each do
    threads << Thread.new do
      uri = URI.parse(HotTub::Server.url)
      pool.run{|connection| Thread.current[:status] = connection.get(:path => uri.path).status }
    end
  end
  threads.each do |t|
    t.join
  end
end
