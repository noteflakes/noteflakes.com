# frozen_string_literal: true

require 'bundler/setup'
require 'tipi'
require 'impression'

PAGES_DIR = File.join(__dir__, 'site/pages')
ASSETS_DIR = File.join(__dir__, 'site/_assets')

$development = ENV['dev'] == '1'

pages = Impression::Pages.new(PAGES_DIR, auto_reload: true)

app = proc do |req|
  p [req.host, req.path]
  req.route do
    if req.host != 'noteflakes.com'
      p reject_host: req.host
      req.reject(nil, Qeweney::Status::SERVICE_UNAVAILABLE)
    end
    req.on('assets') { req.serve_file(req.route_relative_path, base_path: ASSETS_DIR) }
    req.default { pages.serve(req) }
  end
end

Tipi.full_service(&app)
