# frozen_string_literal: true

export self

require 'kramdown'
require 'rouge'
require 'kramdown-parser-gfm'
require 'impression'
require 'escape_utils'

SITE_DIR = __dir__
ASSETS_DIR = File.join(SITE_DIR, '_assets')

KRAMDOWN_OPTIONS = {
  entity_output: :numeric,
  syntax_highlighter: :rouge,
  input: 'GFM',
  hard_wrap: false
}

INDEX_MD = IO.read(File.join(SITE_DIR, 'index.md'))
INDEX_HTML = Kramdown::Document.new(INDEX_MD, **KRAMDOWN_OPTIONS).to_html

def call(req)
  req.on_root { req.respond(render_index, 'Content-Type' => 'text/html') }
  req.on('assets') { req.serve_file(req.route_relative_path, base_path: ASSETS_DIR) }
end

def render_index
  index_template.render(body: INDEX_HTML)
end

def index_template
  H {
    html {
      head {
        title 'Samedi Culture'
        meta charset: 'utf-8'
        meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
        style 'body { display: none }' # prevent FUOC
        link rel: 'stylesheet', href: '/assets/style.css', type: 'text/css'
      }
      body {
        emit context[:body]
      }
    }
  }
end
