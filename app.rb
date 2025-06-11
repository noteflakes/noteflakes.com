# frozen_string_literal: true

require 'bundler/setup'
require 'tp2'
require 'modulation'

noteflakes  = import('./sites/noteflakes.com/site.rb')
tolkora     = import('./sites/tolkora.net/site.rb')

sites = {
  'noteflakes.com'  => noteflakes,
  'tolkora.net'     => tolkora,
  'localhost:1234'  => tolkora
}

TP2.config do |req|
  site = sites[req.host.downcase]
  site ? site.(req) : respond(nil, ':status' => Qeweney::Status::BAD_REQUEST)
end
TP2.run()

# Tipi.run_sites(
#   'noteflakes.com' => (import './sites/noteflakes.com/site.rb')
# )
