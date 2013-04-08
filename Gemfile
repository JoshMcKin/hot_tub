source "https://rubygems.org"

# Specify your gem's dependencies in http_hot_tub.gemspec
gemspec
gem 'rake'

group :development do
  platform :ruby do
  	gem 'coveralls', :require => false
    gem 'eventmachine'
    gem 'em-http-request', '~> 1.0', :require => 'em-http'
    gem 'em-synchrony', '~> 1.0', :require => ['em-synchrony', 'em-synchrony/em-http']
  end
  platform :jruby do
    gem 'jruby-openssl'
  end
end