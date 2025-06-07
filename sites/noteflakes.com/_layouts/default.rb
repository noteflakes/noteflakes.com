require 'papercraft'

export_default Papercraft.html { |**props|
  html5 {
    head {
      title(props[:title] ? "Noteflakes - #{props[:title]}" : "Noteflakes")
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      style 'body { display: none }' # prevent FUOC
      link rel: 'icon', type: 'image/png', href: '/assets/nf-icon-black.png'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
      link rel: 'alternate', type: 'application/rss+xml', href: '/feeds/rss'
    }
    body {
      header {
        h1 {
          a(href: '/') {
            img src: '/assets/nf-icon-black.png'
            span 'noteflakes'
          }
        }
        ul {
          li 'by Sharon Rosner', class: 'byline'
          li { a 'archive', href: '/archive' }
          li { a 'about', href: '/about' }
          li { a 'RSS feed', href: '/feeds/rss' }
          li { a 'code', href: 'https://github.com/noteflakes', target: '_blank' }
        }
      }
      emit_yield **props
      footer {
        hr
        p {
          span 'Copyright © 2025 Sharon Rosner. This site runs on '
          a 'Impression', href: 'https://github.com/digital-fabric/impression'
          span ' and '
          a 'TP2', href: 'https://github.com/noteflakes/tp2'
          span '.'
        }
      }
    }
  }
}
