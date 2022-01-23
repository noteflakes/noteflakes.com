# frozen_string_literal: true

require 'impression'

site = Impression::Jamstack.new(path: '/', directory: __dir__)
export_default site
