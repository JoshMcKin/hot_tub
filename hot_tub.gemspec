# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hot_tub/version"

Gem::Specification.new do |s|
  s.name        = "hot_tub"
  s.version     = HotTub::VERSION
  s.authors     = ["Joshua Mckinney"]
  s.email       = ["joshmckin@gmail.com"]
  s.homepage    = "https://github.com/JoshMcKin/hot_tub"
  s.license     = "MIT"
  s.summary     = %q{A simple thread-safe http connection pooling gem.}
  s.description = %q{A simple thread-safe http connection pooling gem. Http client options include HTTPClient and EM-Http-Request}

  s.rubyforge_project = "hot_tub"
  s.add_development_dependency "rspec"
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
