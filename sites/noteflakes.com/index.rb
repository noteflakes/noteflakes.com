layout = import './_layouts/default'
big_quote = import './_layouts/big_quote'

export_default layout.apply(title: '') { |resource:, **props|
  emit big_quote

  article_entry = resource.page_list('/articles').reverse.first
  h3 article_entry[:date].strftime('%d·%m·%Y'), class: 'date'
  article {
    h1 { a article_entry[:title], href: article_entry[:url] }
    emit article_entry[:html_content]
  }
  p(id: 'previous-link') {
    a 'Previous articles on Noteflakes', href: '/archive'
  }
}
