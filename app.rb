# frozen_string_literal: true

require 'bundler/setup'
require 'tipi'
require 'modulation'

Tipi.run_sites(
  'noteflakes.com' => (import './sites/noteflakes.com/site.rb')
)
