H {
  html5 {
    head {
      title "Noteflakes: #{context[:page].title}"
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      meta name: 'referrer', content: 'no-referrer'
      style 'body { display: none }' # prevent FUOC
      link rel: 'stylesheet', href: '/assets/style.css', type: 'text/css'
    }
    style 'body { display: none }'
    body {
      header {
        h1 { a 'noteflakes', href: '/' }
        ul {
          li 'by Sharon Rosner', class: 'byline'
          li { a 'archive', href: '/archive' }
          li { a 'code', href: 'https://github.com/ciconia', target: '_blank' }
          li { a 'about', href: '/about' }
        }
      }
      article {
        h1 context[:page].title
        h3 context[:page].attributes['date'], class: 'date'
        emit context[:page].render
      }
    }
    style 'body { display: block }'
  }
}
