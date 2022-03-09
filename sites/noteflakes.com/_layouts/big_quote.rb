require 'papercraft'

quote = <<~EOF
  We are one.
  We are one.
  We are one.
EOF

export_default proc {
  article(class: 'quote_of_the_day') {
    blockquote {
      quote.lines.each { |l| span l; br }
    }
    p {
      span '— '
      a 'Ronit Shefi', href: 'https://www.youtube.com/watch?v=S5QtK_-ZYvQ', target: '\blank'
    }
  }
}
