layout = import './_layouts/default'

export_default layout.apply(title: '') { |resource:, **props|
  quote = <<~EOF
    And I dreamed I saw the bombers
    Riding shotgun in the sky
    And they were turning into butterflies
    Above our nation

    We are stardust
    Billion year old carbon
    We are golden
    Caught in the devil's bargain
    And we've got to get ourselves
    back to the garden
  EOF

  article(class: 'quote_of_the_day') {
    blockquote {
      quote.lines.each { |l| span l; br }
    }
    p {
      span '— '
      a 'Joni Mitchell', href: 'https://www.youtube.com/watch?v=cRjQCvfcXn0', target: '\blank'
    }
  }

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
