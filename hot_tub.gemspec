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
  s.summary     = %q{Flexible connection pooling for Ruby.}
  s.description = %q{Flexible connection pooling for Ruby.}

  s.rubyforge_project = "hot_tub"
  
  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "rspec-autotest"
  s.add_development_dependency "autotest"
  s.add_development_dependency "sinatra"
  s.add_development_dependency "puma", "~> 2.0"
  s.add_development_dependency "excon"
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
