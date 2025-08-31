layout = import './_layout/default'

Landing = -> {
  landing {

    high {
      h1 {
        span('Tailor-made software')
      }
      h2 {
        span('My name is Sharon and I build custom software solutions for my clients.')
      }
    }
    low {
      markdown <<~MD
        **Noteflakes** is my independent software
        company based in France. My main fields of expertise are:

        - Internet-enabled process-control systems.
        - Integration of internet services for industrial and B2B apps.
        - Storage, retrieval and analysis of time series data (for industrial
          and B2B applications).

        I build custom solutions for my clients, based on my many years of
        experience in integrating process-control systems with internet
        platforms in a secure and robust manner. Please feel free to
        [contact](/about#contact) me, I’d love to hear about your project!
      MD
    }
  }
}

LastArticle = -> {
  entry = MODULE.page_list('/articles').select { !it[:atts][:draft] }.last
  atts = entry[:atts]

  hr
  h2 'Recently on noteflakes:'

  h3 atts[:date].strftime('%d·%m·%Y'), class: 'date'
  rtl = atts[:layout] == 'article-rtl' || nil
  article(class: rtl && 'rtl') {
    h1 { a atts[:title], href: atts[:url] }
    markdown entry[:markdown]
  }
  p(id: 'previous-link') {
    a 'Previous articles on Noteflakes', href: '/archive'
  }
}

export layout.apply(title: '') { |**props|
  Landing()
  LastArticle()
}
