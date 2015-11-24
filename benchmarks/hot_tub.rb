$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'benchmark/ips'
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

s1 = HotTub::Pool.new(:size => 1, :max_size => 1, :clean => lambda {|clnt| clnt.clean}) { MocClient.new }
s5 = HotTub::Pool.new(:size => 5, :max_size => 5, :clean => lambda {|clnt| clnt.clean}) { MocClient.new }
s10 = HotTub::Pool.new(:size => 5, :max_size => 10, :clean => lambda {|clnt| clnt.clean}) { MocClient.new }
s0 = HotTub::Pool.new(:size => 5, :clean => lambda {|clnt| clnt.clean}) { MocClient.new }

url = 'http://foo.com'
HotTub.add(url, {:size => 5, :clean => lambda {|clnt| clnt.clean}}) { MocClient.new }

Benchmark.ips do |b|

  b.report("blocking") do
    threads = []
    20.times do
      threads << Thread.new do
        s1.run do |conn|
          conn.get
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end

  b.report("max 5") do
    threads = []
    20.times do
      threads << Thread.new do

        s5.run do |conn|
          conn.get
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end

  b.report("max 10") do
    threads = []
    20.times do
      threads << Thread.new do
        s10.run do |conn|
          conn.get
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end

  b.report("no max") do
    threads = []
    20.times do
      threads << Thread.new do
        s0.run do |conn|
          conn.get
        end
      end
    end
    threads.each do |t|
      t.join
    end
  end

  b.report("HotTub.run") do
    threads = []
    20.times do
      threads << Thread.new do
        HotTub.run(url) do |conn|
          conn.get
        end
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
#             blocking     1.000  i/100ms
#                max 5     2.000  i/100ms
#               max 10     4.000  i/100ms
#               no max     8.000  i/100ms
#           HotTub.run     8.000  i/100ms
# -------------------------------------------------
#             blocking      4.605  (± 0.0%) i/s -     24.000 
#                max 5     22.610  (± 0.0%) i/s -    114.000 
#               max 10     43.922  (± 0.0%) i/s -    220.000 
#               no max     83.448  (± 1.2%) i/s -    424.000 
#           HotTub.run     82.757  (± 2.4%) i/s -    416.000 

# Comparison:
#               no max:       83.4 i/s
#           HotTub.run:       82.8 i/s - 1.01x slower
#               max 10:       43.9 i/s - 1.90x slower
#                max 5:       22.6 i/s - 3.69x slower
#             blocking:        4.6 i/s - 18.12x slower


# rubinius 2.5.8 (2.1.0 bef51ae3 2015-07-14 3.5.1 JI) [x86_64-darwin14.4.0]
# Calculating -------------------------------------
#             blocking     1.000  i/100ms
#                max 5     2.000  i/100ms
#               max 10     4.000  i/100ms
#               no max     8.000  i/100ms
#           HotTub.run     8.000  i/100ms
# -------------------------------------------------
#             blocking      4.619  (± 0.0%) i/s -     24.000 
#                max 5     22.758  (± 0.0%) i/s -    114.000 
#               max 10     44.336  (± 2.3%) i/s -    224.000 
#               no max     85.267  (± 3.5%) i/s -    432.000 
#           HotTub.run     85.012  (± 3.5%) i/s -    424.000 

# Comparison:
#               no max:       85.3 i/s
#           HotTub.run:       85.0 i/s - 1.00x slower
#               max 10:       44.3 i/s - 1.92x slower
#                max 5:       22.8 i/s - 3.75x slower
#             blocking:        4.6 i/s - 18.46x slower


# jruby 9.0.3.0 (2.2.2) 2015-10-21 633c9aa Java HotSpot(TM) 64-Bit Server VM 23.5-b02 on 1.7.0_09-b05 +jit [darwin-x86_64]
# Calculating -------------------------------------
#             blocking     1.000  i/100ms
#                max 5     2.000  i/100ms
#               max 10     4.000  i/100ms
#               no max     6.000  i/100ms
#           HotTub.run     7.000  i/100ms
# -------------------------------------------------
#             blocking      4.580  (± 0.0%) i/s -     23.000 
#                max 5     22.514  (± 4.4%) i/s -    114.000 
#               max 10     43.620  (± 2.3%) i/s -    220.000 
#               no max     72.260  (± 6.9%) i/s -    360.000 
#           HotTub.run     66.509  (±10.5%) i/s -    329.000 

# Comparison:
#               no max:       72.3 i/s
#           HotTub.run:       66.5 i/s - 1.09x slower
#               max 10:       43.6 i/s - 1.66x slower
#                max 5:       22.5 i/s - 3.21x slower
#             blocking:        4.6 i/s - 15.78x slower
