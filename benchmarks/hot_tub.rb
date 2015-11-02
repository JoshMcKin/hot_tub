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
    hot_tub = HotTub.new(:size => 1, :max_size => 1) { MocClient.new }
    1000.times.each  do
      hot_tub.run do |conn|
        conn.get
      end
    end
  end

  b.report("threaded size 5") do
    hot_tub = HotTub.new(:size => 5, :max_size => 5) { MocClient.new }
    threads = []
    50.times.each do
      threads << Thread.new do
        20.times do
          hot_tub.run do |conn|
            conn.get
          end
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end

  b.report("threaded size 5, max 10") do
    hot_tub = HotTub.new(:size => 5, :max_size => 10) { MocClient.new }
    threads = []
    50.times.each do
      threads << Thread.new do
        20.times do
          hot_tub.run do |conn|
            conn.get
          end
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end

  b.report("threaded, size 5, no max") do
    hot_tub = HotTub.new(:size => 5) { MocClient.new }
    threads = []
    50.times.each do
      threads << Thread.new do
        20.times do
          hot_tub.run do |conn|
            conn.get
          end
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end


  b.report("threaded, HotTub.run ") do
    urls = ['http://foo.com','http://bar.com','http://zap.com']
    urls.each do |url|
      HotTub.add(url) { MocClient.new }
    end
    threads = []
    50.times.each do
      threads << Thread.new do
        20.times do
          urls.each do |url|
            HotTub.run(url) do |conn|
              conn.get
            end
          end
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
# single thread              0.070000   0.040000   0.110000 ( 10.859963)
# threaded size 5            0.080000   0.090000   0.170000 (  2.288797)
# threaded size 5, max 10    0.060000   0.060000   0.120000 (  1.197574)
# threaded, size 5, no max   0.030000   0.030000   0.060000 (  0.222523)
# threaded, HotTub.run       0.090000   0.090000   0.180000 (  0.659862)
# --------------------------------------------------- total: 0.640000sec

#                                user     system      total        real
# single thread              0.080000   0.030000   0.110000 ( 10.871813)
# threaded size 5            0.080000   0.090000   0.170000 (  2.228075)
# threaded size 5, max 10    0.060000   0.070000   0.130000 (  1.204607)
# threaded, size 5, no max   0.030000   0.020000   0.050000 (  0.220836)
# threaded, HotTub.run       0.090000   0.080000   0.170000 (  0.670364)


# rubinius 2.5.8 (2.1.0 bef51ae3 2015-07-14 3.5.1 JI) [x86_64-darwin14.4.0]
# Rehearsal ------------------------------------------------------------
# single thread              0.152422   0.059901   0.212323 ( 11.104594)
# threaded size 5            0.204700   0.192881   0.397581 (  2.273955)
# threaded size 5, max 10    0.166915   0.155789   0.322704 (  1.161038)
# threaded, size 5, no max   0.143544   0.055138   0.198682 (  0.233619)
# threaded, HotTub.run       0.184800   0.143068   0.327868 (  0.699002)
# --------------------------------------------------- total: 1.459158sec

#                                user     system      total        real
# single thread              0.146872   0.053339   0.200211 ( 11.129070)
# threaded size 5            0.206160   0.199475   0.405635 (  2.270780)
# threaded size 5, max 10    0.201255   0.163359   0.364614 (  1.205708)
# threaded, size 5, no max   0.066599   0.067142   0.133741 (  0.237895)
# threaded, HotTub.run       0.533596   0.093450   0.627046 (  0.670178)


# jruby 9.0.3.0 (2.2.2) 2015-10-21 633c9aa Java HotSpot(TM) 64-Bit Server VM 23.5-b02 on 1.7.0_09-b05 +jit [darwin-x86_64]
# Rehearsal ------------------------------------------------------------
# single thread              0.760000   0.050000   0.810000 ( 11.191212)
# threaded size 5            0.790000   0.120000   0.910000 (  2.262856)
# threaded size 5, max 10    0.600000   0.080000   0.680000 (  1.160630)
# threaded, size 5, no max   0.360000   0.040000   0.400000 (  0.228086)
# threaded, HotTub.run       0.860000   0.100000   0.960000 (  0.673639)
# --------------------------------------------------- total: 3.760000sec

#                                user     system      total        real
# single thread              0.520000   0.060000   0.580000 ( 11.079422)
# threaded size 5            0.390000   0.100000   0.490000 (  2.235107)
# threaded size 5, max 10    0.290000   0.080000   0.370000 (  1.171805)
# threaded, size 5, no max   0.300000   0.030000   0.330000 (  0.265258)
# threaded, HotTub.run       0.580000   0.090000   0.670000 (  0.672435)
