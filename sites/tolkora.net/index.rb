layout = import '_layout/default'
banner = import '_components/banner'

export layout.apply(title: '') { |**props|
  emit banner

  article = MODULE.page_list('/articles').last
  atts = article[:atts]

  h3 atts[:date].strftime('%d·%m·%Y'), class: 'date'
  article(class: 'rtl') {
    h1 { a atts[:title], href: atts[:url] }
    emit_markdown article[:markdown]
  }
  p(id: 'previous-link') {
    a 'מאמרים קודמים', href: '/archive'
  }
}
