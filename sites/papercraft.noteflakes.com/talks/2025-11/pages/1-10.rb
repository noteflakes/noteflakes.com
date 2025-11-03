# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-09', '1-10', '1-11')

  h3 'Everyone is happy!'

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        #### Developer:

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
        #### Machine:
        
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

  cols(class: 'one') {
    div {
      markdown <<~MD
        - Up to 10x faster than "naive" DSL implementation
        - Compiled code similar to compiled ERB
        - Similar performance as compiled ERB
      MD
    }
  }
}
