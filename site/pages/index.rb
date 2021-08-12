---
title: Noteflakes
---
H {
  articles = context[:pages]
    .select(/^\/articles/)
    .sort_by { |page| page.attributes['date'] }
    .reverse.first(10)

  last_date = nil

  articles.each { |page|
    date = page.attributes['date']
    Object.p date: date
    if date != last_date
      last_date = date
      h3 date.strftime('%d·%m·%Y'), class: 'date'
    end
    article {
      h1 { a page.title, href: page.permalink }
      emit page.render
    }
  }

  footer {
    hr
  }
}
