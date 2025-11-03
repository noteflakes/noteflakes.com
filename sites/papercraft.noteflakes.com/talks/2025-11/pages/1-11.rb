# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-10', '1-11', '1-12')

  h3 'Code as data is the future of DSLs'

  markdown <<~MD
    - Runtime DSL compilation
    - Performance optimization, introspection, transformation
    - More 
  MD

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```ruby
        # Describe the end result
        
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
        ```ruby
        # Describe the operations to be done
        
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
