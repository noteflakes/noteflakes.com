# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav(nil, '0-02')

  hero {
    h1 'Papercraft'
    h2 'Embracing the functional style in Ruby'
  }

  cols(class: 'two-one') {
    div {
      h2 "by Sharon Rosner"
      h4 { a "noteflakes.com", href: "https://noteflakes.com/" }
      h4 { a "github.com/noteflakes", href: "https://github.com/noteflakes" }
      h4 { a "@noteflakes.bsky.social", href: "https://bsky.app/profile/noteflakes.bsky.social" }
    }
    
    div {
      img(class: 'qr', src: "../assets/qr-noteflakes.com.png")
    }
  }
}
