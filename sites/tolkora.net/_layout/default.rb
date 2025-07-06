export template { |**props|
  html5 {
    head {
      title(props[:title] ? "טול קורה - #{props[:title]}" : "טול קורה")
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      style 'body { display: none }' # prevent FUOC
      # link rel: 'icon', type: 'image/png', href: '/assets/nf-icon-black.png'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
      link rel: 'alternate', type: 'application/rss+xml', href: '/feeds/rss'
    }
    body {
      header {
        h1 {
          a(href: '/') {
            span 'טולקורה'
          }
        }
        ul {
          li { a 'מאמרים', href: '/archive' }
          li { a 'אודות', href: '/about' }
          li { a 'רסס', href: '/feeds/rss' }
        }
      }
      emit_yield **props
      footer {
        hr
        p {
          span 'כל הזכויות שמורות. תוכן אתר זה ניתן להעתקה והפצה חופשית בכל מקום באינטרנט, תחת התנאים הבאים:'
          span '- הטקסט מובא במלואו ללא שינויים.'
          span '- שם הכותב המקורי מצויין בראש הטקסט.'
        }
      }
    }
  }
}
