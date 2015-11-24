$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'benchmark/ips'

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


Benchmark.ips do |x|
  x.report("block yield") do
    BlockTest.block_yield { "foo" }
  end
  x.report("block call") do
    BlockTest.block_call { "foo" }
  end
  x.report("block to yield") do
    BlockTest.block_to_yield { "foo" }
  end
  x.report("block to call") do
    BlockTest.block_to_call { "foo" }
  end
  x.compare!
end

# ruby 2.2.3p173 (2015-08-18 revision 51636) [x86_64-darwin14]
# Calculating -------------------------------------
#          block yield   108.249k i/100ms
#           block call    64.448k i/100ms
#       block to yield    64.881k i/100ms
#        block to call    60.643k i/100ms
# -------------------------------------------------
#          block yield      4.655M (± 3.2%) i/s -     23.274M
#           block call      1.262M (± 3.2%) i/s -      6.316M
#       block to yield      1.370M (± 3.8%) i/s -      6.877M
#        block to call      1.174M (± 2.1%) i/s -      5.882M

# Comparison:
#          block yield:  4655424.9 i/s
#       block to yield:  1369839.7 i/s - 3.40x slower
#           block call:  1261742.0 i/s - 3.69x slower
#        block to call:  1173741.8 i/s - 3.97x slower

# rubinius 2.5.8 (2.1.0 bef51ae3 2015-07-14 3.5.1 JI) [x86_64-darwin14.4.0]
# Calculating -------------------------------------
#          block yield   148.685k i/100ms
#           block call   140.704k i/100ms
#       block to yield   163.061k i/100ms
#        block to call   126.667k i/100ms
# -------------------------------------------------
#          block yield      4.162M (± 3.0%) i/s -     20.816M
#           block call      1.886M (± 2.8%) i/s -      9.427M
#       block to yield      2.358M (± 2.1%) i/s -     11.903M
#        block to call      1.678M (± 1.8%) i/s -      8.487M

# Comparison:
#          block yield:  4162250.5 i/s
#       block to yield:  2357928.4 i/s - 1.77x slower
#           block call:  1885832.8 i/s - 2.21x slower
#        block to call:  1678439.6 i/s - 2.48x slower

# jruby 9.0.3.0 (2.2.2) 2015-10-21 633c9aa Java HotSpot(TM) 64-Bit Server VM 23.5-b02 on 1.7.0_09-b05 +jit [darwin-x86_64]
# Calculating -------------------------------------
#          block yield   109.774k i/100ms
#           block call   114.963k i/100ms
#       block to yield   125.225k i/100ms
#        block to call   109.991k i/100ms
# -------------------------------------------------
#          block yield      4.998M (± 6.1%) i/s -     24.919M
#           block call      3.980M (± 5.4%) i/s -     19.889M
#       block to yield      4.532M (± 7.4%) i/s -     22.541M
#        block to call      3.771M (± 4.7%) i/s -     18.808M

# Comparison:
#          block yield:  4997696.4 i/s
#       block to yield:  4531931.2 i/s - 1.10x slower
#           block call:  3979846.8 i/s - 1.26x slower
#        block to call:  3771261.6 i/s - 1.33x slower
