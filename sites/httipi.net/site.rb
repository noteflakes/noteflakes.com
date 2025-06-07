# frozen_string_literal: true

export :call

require 'rubyoshka'

@layout = H {
  html5 {
    head {
      title 'Tipi - a modern web server for Ruby'
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      # style 'body { display: none }' # prevent FUOC
      # link rel: 'icon', type: 'image/png', href: '/assets/nf-icon-black.png'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
      # link rel: 'alternate', type: 'application/rss+xml', href: '/feeds/rss'
    }
    body {
      header {
        div(id: 'banner') {
          emit "<p>#{'&nbsp;' * 7}ooo</p>"
          emit "<p>#{'&nbsp;' * 5}oo</p>"
          emit "<p>#{'&nbsp;' * 3}o</p>"
          emit '<p>&nbsp;\\|/    <b>Tipi - a better web server for a better world</b></p>'
          emit '<p>&nbsp;/ \\</p>'
          emit '<p>/&nbsp;&nbsp;&nbsp;\\</p>'
          hr()
        }
        ul {
          li { a 'archive', href: '/archive' }
          li { a 'about', href: '/about' }
          li { a 'RSS feed', href: '/feeds/rss' }
          li { a 'code', href: 'https://github.com/noteflakes', target: '_blank' }
        }
      }
      footer {
        hr
        p {
          span 'Copyright © 2021 Sharon Rosner. This site runs on '
          a 'Impression', href: 'https://github.com/digital-fabric/impression'
          span ' and '
          a 'Tipi', href: 'https://github.com/digital-fabric/tipi'
          span '.'
        }
      }
    }
  }
}

def render_index
  @layout.render
end

SITE_DIR = __dir__
ASSETS_DIR = File.join(SITE_DIR, '_assets')

def call(req)
  req.on_root { req.respond(render_index, 'Content-Type' => 'text/html') }
  req.on('assets') { req.serve_file(req.route_relative_path, base_path: ASSETS_DIR) }
end
