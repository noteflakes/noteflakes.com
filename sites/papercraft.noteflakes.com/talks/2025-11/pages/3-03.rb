# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('3-02', '3-03', '3-04')

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ### Papercraft
      
        ```ruby
        ->(name) {
          div {
            h1 {
              a "Hello, \#{name}!",
                href: '/foo'
            }
          }
        }
        ```
        - Minimal syntax, easy to read and write
        - Explicit `name` argument
        - Always correct HTML generation: tag formatting, escaping, void elements, etc.
      MD


    }
    div {
      markdown <<~MD
        ### ERB
        
        ```html
        <div>
          <h1>
            <a href="/foo">
              Hello, <%= @name %>!
            </a>
          </h1>
        </div>

        ```

        - Implicit variables / ivars
        - Keep templates in separate files
        - Verbose, harder to read / write
        - Better DX with new tools: Herb/ReactionView
      MD
    }
  }
}
