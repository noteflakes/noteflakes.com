---
title: Noteflakes archive
---
H {
  articles = context[:pages]
    .select(/^\/articles/)
    .sort_by { |page| page.attributes['date'] }
    .reverse

  last_month = nil

  h1 'Previously, on noteflakes'

  articles.each { |page|
    date = page.attributes['date']
    month = date.strftime('%^B %Y')
    if month != last_month
      last_month = month
      h3 month, class: 'month'
    end
    p {
      a page.title, href: page.permalink
      small date.strftime('%d·%m·%Y'), class: 'date'
    }
  }
}

