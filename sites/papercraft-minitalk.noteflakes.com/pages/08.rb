# frozen_string_literal: true

layout = import '_layout/default'

export layout.apply { |**props|
  a('>>>', href: '09', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    markdown <<~Markdown
      ## And it's fast, too!

      Papercraft templates are compiled, just like ERB/ERubi/Herb.

      ```ruby
      ->(name) {
        div {
          h1 {
            a "Hello, \#{name}!", href: '/foo'
          }
        }
      }
      ```

      Compiled code:

      ```ruby
      ->(__buffer__, name) {
        __buffer__.<<("<div><h1><a href=\"/foo\">").
                  .<<(ERB::Escape.html_escape(
                    ("Hello, \#{name}!")
                  ))
                  .<<("</a></h1></div>")
        __buffer__
      }
      ```
    Markdown
  }
}
