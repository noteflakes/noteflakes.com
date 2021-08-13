# frozen_string_literal: true

require 'impression'

module NoteflakesSite
  class << self
    SITE_DIR = File.expand_path('../sites/noteflakes.com', __dir__)
    PAGES_DIR = File.join(SITE_DIR, 'pages')
    ASSETS_DIR = File.join(SITE_DIR, '_assets')
    
    DEV = ENV['dev'] == '1'
    
    PAGES = Impression::Pages.new(PAGES_DIR, auto_reload: true)
    
    def route(req)
      req.on('assets') { req.serve_file(req.route_relative_path, base_path: ASSETS_DIR) }
      req.default { PAGES.serve(req) }
    end
  end
end

