# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://gem.coop'
  gem 'benchmark'
  gem 'benchmark-ips'
end

require 'benchmark/ips'

def access_subscript(path)
  10.times {
    a = path.split('/')
    a[1]
    a[2]
    a[3]
    a[4]
    a[5]
  }
end

def access_shift(path)
  10.times {
    a = path.split('/')
    a.shift
    a.shift
    a.shift
    a.shift
    a.shift
    a.shift    
  }
end

PATH = '/[org]/[repo]/issues/[id]'

Benchmark.ips do |x|
  x.report('#[]')     { access_subscript(PATH) }
  x.report('#shift')  { access_shift(PATH) }

  x.compare!(order: :baseline)
end
