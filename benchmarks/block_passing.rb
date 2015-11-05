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
      BlockTest.block_to_yield { "foo" }
    end
  end
  x.report("block to call") do
    n.times do
      BlockTest.block_to_call { "foo" }
    end
  end
end

# ruby 2.2.3p173 (2015-08-18 revision 51636) [x86_64-darwin14]
# Rehearsal --------------------------------------------------
# block yield      0.170000   0.000000   0.170000 (  0.169354)
# block call       0.670000   0.010000   0.680000 (  0.670445)
# block to yield   0.650000   0.000000   0.650000 (  0.645591)
# block to call    0.750000   0.000000   0.750000 (  0.753102)
# ----------------------------------------- total: 2.250000sec

#                      user     system      total        real
# block yield      0.170000   0.000000   0.170000 (  0.166196)
# block call       0.670000   0.000000   0.670000 (  0.663034)
# block to yield   0.640000   0.000000   0.640000 (  0.644746)
# block to call    0.740000   0.000000   0.740000 (  0.747084)

# rubinius 2.5.8 (2.1.0 bef51ae3 2015-07-14 3.5.1 JI) [x86_64-darwin14.4.0]
# Rehearsal --------------------------------------------------
# block yield      0.153971   0.007521   0.161492 (  0.123423)
# block call       0.482452   0.001687   0.484139 (  0.404527)
# block to yield   0.421112   0.001725   0.422837 (  0.317573)
# block to call    0.515777   0.001130   0.516907 (  0.454804)
# ----------------------------------------- total: 1.585375sec

#                      user     system      total        real
# block yield      0.054358   0.000111   0.054469 (  0.054250)
# block call       0.368271   0.000868   0.369139 (  0.368516)
# block to yield   0.281076   0.000553   0.281629 (  0.281446)
# block to call    0.428372   0.000901   0.429273 (  0.428916)

# jruby 9.0.3.0 (2.2.2) 2015-10-21 633c9aa Java HotSpot(TM) 64-Bit Server VM 23.5-b02 on 1.7.0_09-b05 +jit [darwin-x86_64]
# Rehearsal --------------------------------------------------
# block yield      0.400000   0.010000   0.410000 (  0.265343)
# block call       0.370000   0.000000   0.370000 (  0.300598)
# block to yield   0.280000   0.010000   0.290000 (  0.238879)
# block to call    0.400000   0.000000   0.400000 (  0.288711)
# ----------------------------------------- total: 1.470000sec

#                      user     system      total        real
# block yield      0.190000   0.000000   0.190000 (  0.185705)
# block call       0.230000   0.000000   0.230000 (  0.227818)
# block to yield   0.200000   0.000000   0.200000 (  0.206645)
# block to call    0.250000   0.000000   0.250000 (  0.244579)