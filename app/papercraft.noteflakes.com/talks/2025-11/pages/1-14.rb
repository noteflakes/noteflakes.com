# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-13', '1-14', '1-15')

  h3 'Side effects as data'

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        #### Shell:

        ```ruby
        # controller
        def todos_list(req)
          validate_
        end
        ```

        - Describe the return value.

      MD
    }
    div {
      markdown <<~MD
        #### Imperative:
        
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

        - Execute a sequence of operations.
      MD
    }
  }
}
