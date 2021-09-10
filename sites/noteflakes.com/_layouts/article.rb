H {
  html5 {
    head {
      title "Noteflakes: #{context[:page].title}"
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      meta name: 'referrer', content: 'no-referrer'
      link rel: 'icon', type: 'image/png', href: '/assets/nf-icon-black.png'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
      link rel: 'alternate', type: 'application/rss+xml', href: '/feeds/rss'
      style 'body { display: none }' # prevent FUOC
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
          li { a 'code', href: 'https://github.com/ciconia', target: '_blank' }
        }
      }
  
      article {
        h1 context[:page].title
        date = context[:page].attributes['date']
        h3 date.strftime('%d·%m·%Y'), class: 'date'
        emit context[:page].render
      }

      # prev_page = context[:page].prev_page
      # div(class: 'previously') {
      #   span 'Previously: '
      #   a prev_page.title, href: prev_page.permalink
      # } if prev_page

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
