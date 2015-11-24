$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'benchmark/ips'
require 'hot_tub'
require 'connection_pool'

class MocClient;end

puts `ruby -v`

Benchmark.ips do |b|

  ht_no_max = HotTub::Pool.new(:size => 5, :name => "Match Concurrency") { MocClient.new }
  b.report("HotTub::Pool - *") do
    threads = []
    20.times do
      threads << Thread.new do
        ht_no_max.run { |conn| sleep(0.01)}
      end
    end
    threads.each do |t|
      t.join
    end
  end

  ht_sized = HotTub::Pool.new(:size => 5, :max_size => 5, :name => "Limited") { MocClient.new }
  b.report("HotTub::Pool - 5") do
    threads = []
    20.times do
      threads << Thread.new do
        ht_sized.run { |conn| sleep(0.01)}
      end
    end
    threads.each do |t|
      t.join
    end
  end

  cp_t = ConnectionPool.new(:size => 5) { MocClient.new }
  b.report("ConnectionPool - 5") do
    threads = []
    20.times do
      threads << Thread.new do
        cp_t.with { |conn| sleep(0.01)}
      end
    end
    threads.each do |t|
      t.join
    end
  end

  b.compare!
end

# ruby 2.2.3p173 (2015-08-18 revision 51636) [x86_64-darwin14]
# Calculating -------------------------------------
#     HotTub::Pool - *     7.000  i/100ms
#     HotTub::Pool - 5     2.000  i/100ms
#   ConnectionPool - 5     2.000  i/100ms
# -------------------------------------------------
#     HotTub::Pool - *     80.183  (± 2.5%) i/s -    406.000 
#     HotTub::Pool - 5     22.229  (± 0.0%) i/s -    112.000 
#   ConnectionPool - 5     21.886  (± 0.0%) i/s -    110.000 

# Comparison:
#     HotTub::Pool - *:       80.2 i/s
#     HotTub::Pool - 5:       22.2 i/s - 3.61x slower
#   ConnectionPool - 5:       21.9 i/s - 3.66x slower


# jruby 9.0.3.0 (2.2.2) 2015-10-21 633c9aa Java HotSpot(TM) 64-Bit Server VM 23.5-b02 on 1.7.0_09-b05 +jit [darwin-x86_64]
# Calculating -------------------------------------
#     HotTub::Pool - *     6.000  i/100ms
#     HotTub::Pool - 5     2.000  i/100ms
#   ConnectionPool - 5     2.000  i/100ms
# -------------------------------------------------
#     HotTub::Pool - *     69.232  (± 8.7%) i/s -    342.000 
#     HotTub::Pool - 5     22.064  (± 4.5%) i/s -    112.000 
#   ConnectionPool - 5     22.036  (± 0.0%) i/s -    112.000 

# Comparison:
#     HotTub::Pool - *:       69.2 i/s
#     HotTub::Pool - 5:       22.1 i/s - 3.14x slower
#   ConnectionPool - 5:       22.0 i/s - 3.14x slower


# rubinius 2.5.8 (2.1.0 bef51ae3 2015-07-14 3.5.1 JI) [x86_64-darwin14.4.0]
# Calculating -------------------------------------
#     HotTub::Pool - *     8.000  i/100ms
#     HotTub::Pool - 5     2.000  i/100ms
#   ConnectionPool - 5     2.000  i/100ms
# -------------------------------------------------
#     HotTub::Pool - *     84.235  (± 3.6%) i/s -    424.000 
#     HotTub::Pool - 5     22.255  (± 0.0%) i/s -    112.000 
#   ConnectionPool - 5     22.259  (± 0.0%) i/s -    112.000 

# Comparison:
#     HotTub::Pool - *:       84.2 i/s
#   ConnectionPool - 5:       22.3 i/s - 3.78x slower
#     HotTub::Pool - 5:       22.3 i/s - 3.78x slower
