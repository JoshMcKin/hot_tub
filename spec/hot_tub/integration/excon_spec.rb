require 'spec_helper'
describe HotTub do

  context "blocking (size equals max_size)" do
    let(:pool) do
      HotTub::Pool.new(:size => 4, :max_size => 4) {
        Excon.new(HotTub::Server.url, :thread_safe_sockets => false)
      }
    end

    let(:threads) { [] }

    before(:each) do
      20.times do
        excon_thread_work(pool, 10, threads)
      end
    end

    it { expect(pool.current_size).to eql(4) }

    it "should work" do
      results = threads.collect{ |t| t[:status]}
      expect(results.length).to eql(200)
      expect(results.uniq).to eql([200])
    end

    it "should shutdown" do
      pool.shutdown!
      expect(pool.current_size).to eql(0)
    end
  end

  context "with larger max" do
    let(:pool) do
      HotTub::Pool.new(:size => 4, :max_size => 8) {
        Excon.new(HotTub::Server.url, :thread_safe_sockets => false)
      }
    end

    let(:threads) { [] }

    before(:each) do
      20.times do
        excon_thread_work(pool, 10, threads)
      end
    end

    it { expect(pool.current_size).to be >= 4 }

    it { expect(pool.current_size).to be <= 8 }

    it "should reap" do
      pool.reap!
      expect(pool.current_size).to be <= 4
    end

    it "should work" do
      results = threads.collect{ |t| t[:status]}
      expect(results.length).to eql(200)
      expect(results.uniq).to eql([200])
    end
  end

  context "sized without max" do
    let(:pool) do
      HotTub::Pool.new(:size => 4) {
        Excon.new(HotTub::Server.url, :thread_safe_sockets => false)
      }
    end

    let(:threads) { [] }

    before(:each) do
      20.times do
        excon_thread_work(pool, 10, threads)
      end
    end

    it { expect(pool.current_size).to be > 4 }

    it "should reap" do
      pool.reap!
      expect(pool.current_size).to eql(4)
    end

    it "should work" do
      results = threads.collect{ |t| t[:status]}
      expect(results.length).to eql(200)
      expect(results.uniq).to eql([200])
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
