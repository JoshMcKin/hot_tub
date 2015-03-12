$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'benchmark'
require 'hot_tub'
require 'connection_pool'

class MocClient
  def initialize(url=nil,options={})
    @reaped = false
    @close = false
    @clean = false
  end

  # Perform an IO
  def get
    sleep(0.01)
  end

  def close
    @close = true
  end

  def closed?
    @close == true
  end

  def clean
    @clean = true
  end

  def cleaned?
    @clean == true
  end

  def reap
    @reaped = true
  end

  def reaped?
    @reaped
  end
end

puts `ruby -v`
Benchmark.bmbm do |b|

  b.report("hot_tub - single thread") do
    hot_tub = HotTub::Pool.new(:size => 1, :max_size => 1, :no_reaper => true) { MocClient.new }
    1000.times.each  do
      hot_tub.run do |conn|
        conn.get
      end
    end
  end

  b.report("co_pool - single thread") do
    connection_pool = ConnectionPool.new(:size => 1) { MocClient.new}
    1000.times.each  do
      connection_pool.with do |conn|
        conn.get
      end
    end
  end


  b.report("hot_tub - threaded pool size = 5") do
    hot_tub = HotTub::Pool.new(:size => 5, :max_size => 5, :no_reaper => true) { MocClient.new }
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

  b.report("co_pool - threaded pool size = 5") do
    connection_pool = ConnectionPool.new(:size => 5) { MocClient.new}
    threads = []
    1000.times.each do
      threads << Thread.new do
        connection_pool.with do |conn|
          conn.get
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end

  b.report("hot_tub - threaded, max 10") do
    hot_tub = HotTub::Pool.new(:size => 5, :no_reaper => true) { MocClient.new }
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

  b.report("hot_tub - threaded, no max") do
    hot_tub = HotTub::Pool.new(:size => 5, :no_reaper => true) { MocClient.new }
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

# ruby 2.2.1p85 (2015-02-26 revision 49769) [x86_64-darwin13]
# Rehearsal --------------------------------------------------------------------
# hot_tub - single thread            0.110000   0.050000   0.160000 ( 11.022858)
# co_pool - single thread            0.100000   0.040000   0.140000 ( 10.940393)
# hot_tub - threaded pool size = 5   0.190000   0.270000   0.460000 (  2.379666)
# co_pool - threaded pool size = 5   2.500000   5.110000   7.610000 (  4.662645)
# hot_tub - threaded, max 10         0.130000   0.120000   0.250000 (  0.213179)
# hot_tub - threaded, no max         0.140000   0.100000   0.240000 (  0.202775)
# ----------------------------------------------------------- total: 8.860000sec
#
#                                        user     system      total        real
# hot_tub - single thread            0.110000   0.050000   0.160000 ( 10.959836)
# co_pool - single thread            0.110000   0.040000   0.150000 ( 11.031302)
# hot_tub - threaded pool size = 5   0.260000   0.290000   0.550000 (  2.475077)
# co_pool - threaded pool size = 5   2.460000   4.750000   7.210000 (  4.607360)
# hot_tub - threaded, max 10         0.180000   0.110000   0.290000 (  0.244350)
# hot_tub - threaded, no max         0.180000   0.100000   0.280000 (  0.234632)



# ruby 2.1.5p273 (2014-11-13 revision 48405) [x86_64-darwin14.0]
# Rehearsal --------------------------------------------------------------------
# hot_tub - single thread            0.130000   0.050000   0.180000 ( 11.017186)
# co_pool - single thread            0.110000   0.050000   0.160000 ( 11.058659)
# hot_tub - threaded pool size = 5   0.270000   0.300000   0.570000 (  2.477496)
# co_pool - threaded pool size = 5   2.450000   4.580000   7.030000 (  4.456334)
# hot_tub - threaded, max 10         0.180000   0.110000   0.290000 (  0.245525)
# hot_tub - threaded, no max         0.190000   0.180000   0.370000 (  0.289571)
# ----------------------------------------------------------- total: 8.600000sec
#
#                                        user     system      total        real
# hot_tub - single thread            0.120000   0.050000   0.170000 ( 11.034023)
# co_pool - single thread            0.110000   0.040000   0.150000 ( 11.053718)
# hot_tub - threaded pool size = 5   0.350000   0.280000   0.630000 (  2.508310)
# co_pool - threaded pool size = 5   2.560000   4.760000   7.320000 (  4.580944)
# hot_tub - threaded, max 10         0.220000   0.110000   0.330000 (  0.282881)
# hot_tub - threaded, no max         0.220000   0.100000   0.320000 (  0.278094)



# ruby 2.0.0p598 (2014-11-13 revision 48408) [x86_64-darwin13.4.0]
# Rehearsal --------------------------------------------------------------------
# hot_tub - single thread            0.140000   0.060000   0.200000 ( 11.068040)
# co_pool - single thread            0.110000   0.050000   0.160000 ( 11.056149)
# hot_tub - threaded pool size = 5   0.690000   0.390000   1.080000 (  2.920606)
# co_pool - threaded pool size = 5 Timeout::Error: Waited 5 sec
