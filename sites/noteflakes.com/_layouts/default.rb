H {
  html5 {
    head {
      title context[:page].title
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      meta name: 'referrer', content: 'no-referrer'
      link rel: 'icon', type: 'image/png', href: '/assets/nf-icon-black.png'
      style 'body { display: none }' # prevent FUOC
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
    }
    body {
      header {
        h1 { a(href: '/') {
          img src: '/assets/nf-icon-black.png'
          span 'noteflakes'
        } }
        ul {
          li 'by Sharon Rosner', class: 'byline'
          li { a 'archive', href: '/archive' }
          li { a 'code', href: 'https://github.com/ciconia', target: '_blank' }
          li { a 'about', href: '/about' }
          li { a 'RSS feed', href: '/feeds/rss' }
        }
      }
      emit context[:page].render
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
