# frozen_string_literal: true

require 'bundler/setup'
require 'tipi'

require_relative 'lib/noteflakes.com'
require_relative 'lib/h.noteflakes.com'

app = proc do |req|
  p req.headers
  req.route do
    req.on_host('noteflakes.com') { NoteflakesSite.route(req) }
    req.on_host('h.noteflakes.com') { HaaretzFeedSite.route(req) }

    req.reject(nil, Qeweney::Status::SERVICE_UNAVAILABLE)
  end
end

Tipi.full_service(&app)
