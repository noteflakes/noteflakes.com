export(template { |**props|
  html {
    head {
      title 'Papercraft'
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      link rel: 'stylesheet', type: 'text/css', href: '/talks/2025-11/assets/style.css'
    }
    body {
      container {
        render_children(**props)
      }
      auto_refresh_watch!

      script <<~JS
        document.body.addEventListener('keydown', (e) => {
          switch (e.key) {
            case 'ArrowRight':
              return document.querySelector('.next').click();
            case 'ArrowLeft':
              return document.querySelector('.prev').click();
          }
        }, true);
      JS
    }
  }
})
