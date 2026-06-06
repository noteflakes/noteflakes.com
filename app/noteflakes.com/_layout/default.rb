export(template { |page_title: nil, page_description: nil, **props|
  page_title ||= props[:title] ? "#{props[:title]} - Noteflakes" : 'Noteflakes'
  page_description ||= page_title

  html(lang: 'en') {
    head {
      title page_title
      meta charset: 'utf-8'
      meta name: 'description', content: page_description.gsub(/\s+/, ' ').strip
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      link rel: 'icon', type: 'image/png', href: '/assets/nf-icon-black.png'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
      link rel: 'alternate', type: 'application/rss+xml', href: '/feeds/rss'
    }
    body {
      watermelon {
        a(href: '/palestine', title: 'On Palestine') {
          red
          black
          white
          green
        }
      }

      container {
        header {
          h1 {
            a(href: '/') {
              img src: '/assets/nf-icon-black.png', alt: "Noteflakes icon"
              span 'noteflakes'
            }
          }
          ul {
            li { a 'home',      href: '/' }
            li { a 'archive',   href: '/archive' }
            li { a 'about',     href: '/about' }
            li { a 'RSS feed',  href: '/feeds/rss' }
            li { a 'code',      href: 'https://github.com/noteflakes', target: '_blank' }
          }
        }
        render_children(**props)
        footer {
          hr
          p {
            span 'Copyright © 2025 Noteflakes. This site runs on '
            a 'Syntropy', href: 'https://github.com/noteflakes/syntropy'
            span '.'
          }
        }
      }
      auto_refresh_watch!
    }
  }
})
