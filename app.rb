# frozen_string_literal: true

require 'bundler/setup'
require 'tp2'
require 'modulation'

TP2.config(&(import './sites/noteflakes.com/site.rb'))
TP2.run()

# Tipi.run_sites(
#   'noteflakes.com' => (import './sites/noteflakes.com/site.rb')
# )
