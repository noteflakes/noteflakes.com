# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-05', '1-06', '1-07')

  h3 'The Papercraft DSL Implementation'

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        #### DSL:

        ```ruby
        ->(foo, bar) {
          div {
            h1 foo
            p bar
          }
        }
          

        ```    
      MD
    }
    div {
      markdown <<~MD
        #### Compiled:
        
        ```ruby
        ->(__buffer__, foo, bar) {
          __buffer__ << '<div><h1>'
          __buffer__ << ERB::Escape.html_escape(foo)
          __buffer__ << '</h1><p>'
          __buffer__ << ERB::Escape.html_escape(bar)
          __buffer__ << '</p></div>'
          __buffer__
        }
        ```
      MD
    }
  }
}
