export(template do |**props|
  html5 do
    head do
      title(props[:title] ? "Noteflakes - #{props[:title]}" : 'Noteflakes')
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      style 'body { display: none }' # prevent FUOC
      link rel: 'icon', type: 'image/png', href: '/assets/nf-icon-black.png'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
      link rel: 'alternate', type: 'application/rss+xml', href: '/feeds/rss'
    end
    body do
      header do
        h1 do
          a(href: '/') do
            img src: '/assets/nf-icon-black.png'
            span 'noteflakes'
          end
        end
        ul do
          li { a 'archive', href: '/archive' }
          li { a 'about', href: '/about' }
          li { a 'RSS feed', href: '/feeds/rss' }
          li { a 'code', href: 'https://github.com/noteflakes', target: '_blank' }
        end
      end
      emit_yield(**props)
      footer do
        hr
        p do
          span 'Copyright © 2025 Noteflakes. This site runs on '
          a 'Syntropy', href: 'https://github.com/noteflakes/syntropy'
          span '.'
        end
      end
    end
  end
end)
