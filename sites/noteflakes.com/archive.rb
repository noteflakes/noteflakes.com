layout = import './_layouts/default'

export_default layout.apply(title: 'archive') { |resource:, **props|
  article_entries = resource.page_list('/articles').reverse

  last_month = nil

  h1 'Previously, on noteflakes'

  article_entries.each { |e|
    date = e[:date]
    month = date.strftime('%^B %Y')
    if month != last_month
      last_month = month
      h3 month, class: 'month'
    end
    p {
      a e[:title], href: e[:url]
      small date.strftime('%d·%m·%Y'), class: 'date'
    }
  }
}
