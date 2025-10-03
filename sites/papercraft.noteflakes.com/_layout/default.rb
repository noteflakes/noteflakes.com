export template { |page_title: nil, **props|
  html5 {
    head {
      title(page_title ? "Papercraft - #{page_title}" : 'Papercraft - Functional HTML Templating for Ruby')
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
    }
    body {
      render_children(**props)
    }
    auto_refresh_watch!
  }
}
