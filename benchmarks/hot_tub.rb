$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'benchmark'
require 'hot_tub'

class MocClient
  def initialize(url=nil,options={})
  end

  def get
    sleep(0.01)
  end
end

puts `ruby -v`
Benchmark.bmbm do |b|

  b.report("single thread") do
    hot_tub = HotTub::Pool.new(:size => 1, :max_size => 1, :no_reaper => true) { MocClient.new }
    1000.times.each  do
      hot_tub.run do |conn|
        conn.get
      end
    end
  end

  b.report("threaded size 5") do
    hot_tub = HotTub::Pool.new(:size => 5, :max_size => 5) { MocClient.new }
    threads = []
    1000.times.each do
      threads << Thread.new do
        hot_tub.run do |conn|
          conn.get
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end

  b.report("threaded size 5, max 10") do
    hot_tub = HotTub::Pool.new(:size => 5, :max_size => 10) { MocClient.new }
    threads = []
    1000.times.each do
      threads << Thread.new do
        hot_tub.run do |conn|
          conn.get
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end

  b.report("threaded, size 5, no max") do
    hot_tub = HotTub::Pool.new(:size => 5) { MocClient.new }
    threads = []
    1000.times.each do
      threads << Thread.new do
        hot_tub.run do |conn|
          conn.get
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end

end

