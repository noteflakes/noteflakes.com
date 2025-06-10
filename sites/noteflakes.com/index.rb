layout = import './_layouts/default'
banner = import './_components/banner'

export_default layout.apply(title: '') { |resource:, **props|
  emit banner

  article_entry = resource.page_list('/articles').reverse.first

  h3 article_entry[:date].strftime('%d·%m·%Y'), class: 'date'
  rtl = article_entry[:layout] == 'article-rtl' || nil
  article(class: rtl && 'rtl') {
    h1 { a article_entry[:title], href: article_entry[:url] }
    emit article_entry[:html_content]
  }
  p(id: 'previous-link') {
    a 'Previous articles on Noteflakes', href: '/archive'
  }
}
