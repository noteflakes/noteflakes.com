layout = import './_layout/default'
banner = import './_components/banner'


export layout.apply(title: '') { |**props|
  emit banner

  entry = MODULE.page_list('/articles').last
  atts = entry[:atts]

  h3 atts[:date].strftime('%d·%m·%Y'), class: 'date'
  rtl = atts[:layout] == 'article-rtl' || nil
  article(class: rtl && 'rtl') {
    h1 { a atts[:title], href: atts[:url] }
    emit_markdown entry[:markdown]
  }
  p(id: 'previous-link') {
    a 'Previous articles on Noteflakes', href: '/archive'
  }
}
