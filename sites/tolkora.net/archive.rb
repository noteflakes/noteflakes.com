layout = import '_layout/default'

export layout.apply(title: 'archive') { |**props|
  article_entries = MODULE.page_list('/articles').reverse

  last_month = nil

  h1 'מאמרים בטולקורה'

  article_entries.each { |e|
    atts = e[:atts]
    date = atts[:date]
    rtl = atts[:layout] == 'article-rtl' || nil
    month = date.strftime('%m/%Y')
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
