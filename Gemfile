source "https://rubygems.org"

# Specify your gem's dependencies in http_hot_tub.gemspec
gemspec
gem 'rake'
gem 'thread_safe'
group :development do
  platform :ruby do
  	gem 'coveralls', :require => false
  end
  platform :jruby do
    gem 'jruby-openssl'
  end
end