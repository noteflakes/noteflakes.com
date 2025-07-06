# frozen_string_literal: true

require 'impression'

site = Impression::App.new(path: '/', directory: __dir__)
export_default site
