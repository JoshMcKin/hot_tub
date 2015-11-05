$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'benchmark'
require 'hot_tub'

class MocClient
  def initialize(url=nil,options={})
  end

  def get
    sleep(0.01)
  end

  def clean
    @clean = true
  end

end

puts `ruby -v`

Benchmark.bmbm do |b|

  b.report("single thread") do
    hot_tub = HotTub.new(:size => 1, :max_size => 1, :clean => lambda {|clnt| clnt.clean}) { MocClient.new }
    1000.times.each  do
      hot_tub.run do |conn|
        conn.get
      end
    end
  end

  b.report("threaded size 5") do
    hot_tub = HotTub.new(:size => 5, :max_size => 5, :clean => lambda {|clnt| clnt.clean}) { MocClient.new }
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
    hot_tub = HotTub.new(:size => 5, :max_size => 10, :clean => lambda {|clnt| clnt.clean}) { MocClient.new }
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
    hot_tub = HotTub.new(:size => 5, :clean => lambda {|clnt| clnt.clean}) { MocClient.new }
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
      HotTub.add(url, {:clean => lambda {|clnt| clnt.clean}}) { MocClient.new }
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
# single thread              0.090000   0.050000   0.140000 ( 11.056805)
# threaded size 5            0.110000   0.130000   0.240000 (  2.323854)
# threaded size 5, max 10    0.080000   0.100000   0.180000 (  1.162047)
# threaded, size 5, no max   0.030000   0.040000   0.070000 (  0.229230)
# threaded, HotTub.run       0.130000   0.120000   0.250000 (  0.673286)
# --------------------------------------------------- total: 0.880000sec

#                                user     system      total        real
# single thread              0.080000   0.040000   0.120000 ( 10.908496)
# threaded size 5            0.110000   0.130000   0.240000 (  2.314875)
# threaded size 5, max 10    0.080000   0.100000   0.180000 (  1.202064)
# threaded, size 5, no max   0.040000   0.040000   0.080000 (  0.224133)
# threaded, HotTub.run       0.120000   0.120000   0.240000 (  0.670526)


# rubinius 2.5.8 (2.1.0 bef51ae3 2015-07-14 3.5.1 JI) [x86_64-darwin14.4.0]
# Rehearsal ------------------------------------------------------------
# single thread              0.427639   0.053404   0.481043 ( 11.049242)
# threaded size 5            0.214155   0.201618   0.415773 (  2.255010)
# threaded size 5, max 10    0.170088   0.158815   0.328903 (  1.159579)
# threaded, size 5, no max   0.132440   0.046240   0.178680 (  0.240322)
# threaded, HotTub.run       0.169417   0.123085   0.292502 (  0.676492)
# --------------------------------------------------- total: 1.696901sec

#                                user     system      total        real
# single thread              0.155789   0.054654   0.210443 ( 11.052989)
# threaded size 5            0.253045   0.209961   0.463006 (  2.276732)
# threaded size 5, max 10    0.149159   0.138857   0.288016 (  1.171204)
# threaded, size 5, no max   0.216853   0.033597   0.250450 (  0.224729)
# threaded, HotTub.run       0.626503   0.080910   0.707413 (  0.664893)


# jruby 9.0.3.0 (2.2.2) 2015-10-21 633c9aa Java HotSpot(TM) 64-Bit Server VM 23.5-b02 on 1.7.0_09-b05 +jit [darwin-x86_64]
# Rehearsal ------------------------------------------------------------
# single thread              0.890000   0.070000   0.960000 ( 11.343993)
# threaded size 5            0.850000   0.130000   0.980000 (  2.324202)
# threaded size 5, max 10    0.710000   0.110000   0.820000 (  1.178593)
# threaded, size 5, no max   0.320000   0.050000   0.370000 (  0.233405)
# threaded, HotTub.run       1.190000   0.100000   1.290000 (  0.683554)
# --------------------------------------------------- total: 4.420000sec

#                                user     system      total        real
# single thread              0.350000   0.060000   0.410000 ( 11.156489)
# threaded size 5            0.540000   0.130000   0.670000 (  2.251505)
# threaded size 5, max 10    0.300000   0.100000   0.400000 (  1.153055)
# threaded, size 5, no max   0.270000   0.050000   0.320000 (  0.230043)
# threaded, HotTub.run       0.360000   0.110000   0.470000 (  0.674920)
