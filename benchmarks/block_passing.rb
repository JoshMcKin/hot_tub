$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'benchmark'

puts `ruby -v`


# HotTub uses persisted blocks in several places.

# Tests performance of passing a known block to block call or yield.

class BlockTest
  class << self
    def block_to_yield &block
      block_yield &block
    end

    def block_to_call &block
      block_call &block
    end

    def block_yield
      yield
    end

    def block_call &block
      block.call
    end
  end
end


n = 1_000_000
Benchmark.bmbm do |x|
  x.report("block yield") do
    n.times do
      BlockTest.block_yield { "foo" }
    end
  end
  x.report("block call") do
    n.times do
      BlockTest.block_call { "foo" }
    end
  end
  x.report("block to yield") do
    n.times do
      BlockTest.block_yield { "foo" }
    end
  end
  x.report("block to call") do
    n.times do
      BlockTest.block_call { "foo" }
    end
  end
end

# ruby 2.2.3p173 (2015-08-18 revision 51636) [x86_64-darwin14]
# Rehearsal --------------------------------------------------
# block yield      0.160000   0.000000   0.160000 (  0.166351)
# block call       0.690000   0.000000   0.690000 (  0.684485)
# block to yield   0.160000   0.000000   0.160000 (  0.166744)
# block to call    0.680000   0.000000   0.680000 (  0.677085)
# ----------------------------------------- total: 1.690000sec

#                      user     system      total        real
# block yield      0.160000   0.000000   0.160000 (  0.165289)
# block call       0.690000   0.010000   0.700000 (  0.699424)
# block to yield   0.180000   0.000000   0.180000 (  0.172781)
# block to call    0.700000   0.010000   0.710000 (  0.702157)

# rubinius 2.5.8 (2.1.0 bef51ae3 2015-07-14 3.5.1 JI) [x86_64-darwin14.4.0]
# Rehearsal --------------------------------------------------
# block yield      0.164459   0.009985   0.174444 (  0.136798)
# block call       0.396599   0.001442   0.398041 (  0.374256)
# block to yield   0.095014   0.000532   0.095546 (  0.068005)
# block to call    0.386417   0.001135   0.387552 (  0.370419)
# ----------------------------------------- total: 1.055583sec

#                      user     system      total        real
# block yield      0.050738   0.000172   0.050910 (  0.050869)
# block call       0.359893   0.000935   0.360828 (  0.360429)
# block to yield   0.050676   0.000181   0.050857 (  0.050787)
# block to call    0.360640   0.001018   0.361658 (  0.361311)

# jruby 9.0.3.0 (2.2.2) 2015-10-21 633c9aa Java HotSpot(TM) 64-Bit Server VM 23.5-b02 on 1.7.0_09-b05 +jit [darwin-x86_64]
# Rehearsal --------------------------------------------------
# block yield      0.410000   0.010000   0.420000 (  0.260548)
# block call       0.420000   0.000000   0.420000 (  0.356582)
# block to yield   0.220000   0.000000   0.220000 (  0.189081)
# block to call    0.360000   0.010000   0.370000 (  0.266201)
# ----------------------------------------- total: 1.430000sec

#                      user     system      total        real
# block yield      0.170000   0.000000   0.170000 (  0.173698)
# block call       0.220000   0.000000   0.220000 (  0.222841)
# block to yield   0.180000   0.000000   0.180000 (  0.172968)
# block to call    0.220000   0.000000   0.220000 (  0.224151)