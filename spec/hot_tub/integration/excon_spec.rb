require 'spec_helper'

describe HotTub do

  context "blocking (size equals max_size)" do
    let(:pool) do
      HotTub.new(:size => 4, :max_size => 4) {
        Excon.new(HotTub::Server.url, :thread_safe_sockets => false)
      }
    end

    it "should work" do
      threads = []
      5.times do
        excon_thread_work(pool, 20, threads)
      end
      expect(pool.current_size).to eql(4) # make sure the pool grew beyond size
      results = threads.collect{ |t| t[:status]}
      expect(results.length).to eql(100) # make sure all threads are present
      expect(results.uniq).to eql([200]) # make sure all returned status 200
    end
  end

  context "with larger max" do
    let(:pool) do
      HotTub.new(:size => 4, :max_size => 8) {
        Excon.new(HotTub::Server.url, :thread_safe_sockets => false)
      }
    end

    it "should work" do
      threads = []
      5.times do
        excon_thread_work(pool, 20, threads)
      end
      expect(pool.current_size).to be >= 4
      expect(pool.current_size).to be <= 8
      pool.reap!
      expect(pool.current_size).to eql(4)
      results = threads.collect{ |t| t[:status]}
      expect(results.length).to eql(100) # make sure all threads are present
      expect(results.uniq).to eql([200]) # make sure all returned status 200
    end
  end

  context "sized without max" do
    let(:pool) do
      HotTub.new(:size => 4) {
        Excon.new(HotTub::Server.url, :thread_safe_sockets => false)
      }
    end

    it "should work" do
      threads = []
      5.times do
        excon_thread_work(pool, 20, threads)
      end
      expect(pool.current_size).to be > 4 # make sure the pool grew beyond size
      pool.reap!
      expect(pool.current_size).to eql(4)
      results = threads.collect{ |t| t[:status]}
      expect(results.length).to eql(100) # make sure all threads are present
      expect(results.uniq).to eql([200]) # make sure all returned status 200
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
