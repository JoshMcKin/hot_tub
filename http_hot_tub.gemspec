# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hot_tub/version"

Gem::Specification.new do |s|
  s.name        = "hot_tub"
  s.version     = HotTub::VERSION
  s.authors     = ["Joshua Mckinney"]
  s.email       = ["joshmckin@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{A very simple ruby pool gem}
  s.description = %q{A very simple ruby pool gem}

  s.rubyforge_project = "http_hot_tub"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_development_dependency "rspec"
end
