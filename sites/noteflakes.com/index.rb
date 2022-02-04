layout = import './_layouts/default'
big_quote = import './_layouts/big_quote'

export_default layout.apply(title: '') { |resource:, **props|
  emit big_quote

  article_entries = resource.page_list('/articles').reverse.first(10)

  last_date = nil

  article_entries.each { |e|
    date = e[:date]
    if date != last_date
      last_date = date
      h3 date.strftime('%d·%m·%Y'), class: 'date'
    end
    article {
      h1 { a e[:title], href: e[:url] }
      emit e[:html_content]
    }
  }
}
