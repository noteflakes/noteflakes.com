# frozen_string_literal: true

layout = import '_layout/default'

export layout.apply { |**props|
  a('>>>', href: '04', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    h2 'How does it compare?'
  }
  div(class: 'split') {
    div {
      markdown <<~MD
        ## Papercraft
      
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
        - Explicit `name` argument
        - Generate HTML right in your Ruby code
        - Minimal syntax, easy to read and write
      MD


    }
    div {
      markdown <<~MD
        ## ERB/Erubi
        
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
