# frozen_string_literal: true

layout = import '_layout/default'

export layout.apply { |**props|
  a('>>>', href: '02', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    markdown <<~MD
      # Papercraft

      ## Functional HTML Templating for Ruby
      
      ```ruby
      -> {
        h1 "Hello, Euruko!"

        h2 "My name is Sharon"

        p {
          a "aka noteflakes", href: "github.com/noteflakes"
        }
      }
      ```

    MD
  }
}
