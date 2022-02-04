require 'papercraft'

quote = <<~EOF
  There's a place for us,
  Somewhere a place for us.
  Peace and quiet and open air
  Wait for us somewhere.

  There's a time for us,
  Someday a time for us.
  Time together with time to spare,
  Time to learn, time to care.

  Someday, somewhere
  We'll find a new way of living,
  We'll find a way of forgiving,
  Somewhere.
EOF

export_default proc {
  article(class: 'quote_of_the_day') {
    blockquote {
      quote.lines.each { |l| span l; br }
    }
    p {
      span '— '
      a 'Sondheim/Bernstein (West Side Story)', href: 'https://www.youtube.com/watch?v=0XfOLQVuwaE', target: '\blank'
    }
  }
}
