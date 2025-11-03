# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-01', '1-02', '1-03')

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
        
        - Always correct HTML formatting.
        - Minimal syntax, easy to read and write.
        - Explicit arguments.
        - Organize your templates however you want.
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

        - Error prone.
        - Verbose, harder to read / write.
        - Implicit variables / ivars.
        - Keep templates in separate files.
      MD
    }
  }
}
