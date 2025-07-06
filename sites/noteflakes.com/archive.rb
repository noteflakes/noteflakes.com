# frozen_string_literal: true

layout = import './_layout/default'

export layout.apply(title: 'archive') {
  articles = MODULE.page_list('/articles').reverse
  Kernel.puts
  Kernel.p articles: articles
  Kernel.puts

  last_month = nil

  h1 'Previously, on noteflakes'

  articles.each { |a|
    atts = a[:atts]
    date = atts[:date]
    rtl = atts[:layout] == 'article-rtl' || nil
    month = date.strftime('%^B %Y')
    if month != last_month
      last_month = month
      h3 month, class: 'month'
    end
    p {
      span(class: rtl && 'rtl') { a atts[:title], href: atts[:url] }
      small date.strftime('%d·%m·%Y'), class: 'date'
    }
  }
}
