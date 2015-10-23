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

# ruby 2.2.3p173 (2015-08-18 revision 51636) [x86_64-darwin14]
# Rehearsal ------------------------------------------------------------
# single thread              0.110000   0.040000   0.150000 ( 10.998645)
# threaded size 5            0.250000   0.320000   0.570000 (  2.490553)
# threaded size 5, max 10    0.220000   0.290000   0.510000 (  1.372965)
# threaded, size 5, no max   0.140000   0.130000   0.270000 (  0.240067)
# --------------------------------------------------- total: 1.500000sec

#                                user     system      total        real
# single thread              0.110000   0.050000   0.160000 ( 11.009793)
# threaded size 5            0.320000   0.320000   0.640000 (  2.559244)
# threaded size 5, max 10    0.300000   0.270000   0.570000 (  1.454562)
# threaded, size 5, no max   0.200000   0.130000   0.330000 (  0.280806)


# rubinius 2.5.8 (2.1.0 bef51ae3 2015-07-14 3.5.1 JI) [x86_64-darwin14.4.0]
# Rehearsal ------------------------------------------------------------
# single thread              0.182959   0.057407   0.240366 ( 11.014685)
# threaded size 5            0.374537   0.274944   0.649481 (  2.251464)
# threaded size 5, max 10    0.216058   0.215593   0.431651 (  1.137440)
# threaded, size 5, no max   0.173595   0.120422   0.294017 (  0.086586)
# --------------------------------------------------- total: 1.615515sec

#                                user     system      total        real
# single thread              0.177439   0.056605   0.234044 ( 11.031641)
# threaded size 5            0.273678   0.302949   0.576627 (  2.274915)
# threaded size 5, max 10    0.212687   0.204235   0.416922 (  1.130088)
# threaded, size 5, no max   0.138528   0.095331   0.233859 (  0.065469)


# jruby 9.0.3.0 (2.2.2) 2015-10-21 633c9aa Java HotSpot(TM) 64-Bit Server VM 23.5-b02 on 1.7.0_09-b05 +jit [darwin-x86_64]
# Rehearsal ------------------------------------------------------------
# single thread              1.160000   0.070000   1.230000 ( 11.521177)
# threaded size 5            1.280000   0.370000   1.650000 (  2.450701)
# threaded size 5, max 10    0.840000   0.310000   1.150000 (  1.167782)
# threaded, size 5, no max   0.600000   0.160000   0.760000 (  0.173616)
# --------------------------------------------------- total: 4.790000sec

#                                user     system      total        real
# single thread              0.780000   0.080000   0.860000 ( 11.264802)
# threaded size 5            0.560000   0.340000   0.900000 (  2.269302)
# threaded size 5, max 10    0.610000   0.320000   0.930000 (  1.168468)
# threaded, size 5, no max   0.300000   0.150000   0.450000 (  0.150489)

