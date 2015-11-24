$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'benchmark/ips'
require 'hot_tub'
require 'connection_pool'

class MocClient;end

puts `ruby -v`

Benchmark.ips do |b|

  ht_1 = HotTub::Pool.new(:size => 1) { MocClient.new }
  b.report("HotTub::Pool") do
    ht_1.run { |conn| }
  end

  cp_1 = ConnectionPool.new(:size => 1) { MocClient.new }
  b.report("ConnectionPool") do
    cp_1.with { |conn| }
  end
  b.compare!
end

# ruby 2.2.3p173 (2015-08-18 revision 51636) [x86_64-darwin14]
# Calculating -------------------------------------
#         HotTub::Pool    26.909k i/100ms
#       ConnectionPool    10.413k i/100ms
# -------------------------------------------------
#         HotTub::Pool    351.352k (± 1.9%) i/s -      1.776M
#       ConnectionPool    122.342k (± 1.2%) i/s -    614.367k

# Comparison:
#         HotTub::Pool:   351352.4 i/s
#       ConnectionPool:   122341.6 i/s - 2.87x slower


# jruby 9.0.3.0 (2.2.2) 2015-10-21 633c9aa Java HotSpot(TM) 64-Bit Server VM 23.5-b02 on 1.7.0_09-b05 +jit [darwin-x86_64]
# Calculating -------------------------------------
#         HotTub::Pool    16.145k i/100ms
#       ConnectionPool     6.260k i/100ms
# -------------------------------------------------
#         HotTub::Pool    304.280k (± 3.7%) i/s -      1.534M
#       ConnectionPool    106.788k (± 2.6%) i/s -    538.360k

# Comparison:
#         HotTub::Pool:   304279.7 i/s
#       ConnectionPool:   106788.5 i/s - 2.85x slower


# rubinius 2.5.8 (2.1.0 bef51ae3 2015-07-14 3.5.1 JI) [x86_64-darwin14.4.0]
# Calculating -------------------------------------
#         HotTub::Pool    12.259k i/100ms
#       ConnectionPool     8.771k i/100ms
# -------------------------------------------------
#         HotTub::Pool    415.132k (± 2.9%) i/s -      2.072M
#       ConnectionPool    172.584k (± 1.7%) i/s -    868.329k

# Comparison:
#         HotTub::Pool:   415131.6 i/s
#       ConnectionPool:   172584.0 i/s - 2.41x slower