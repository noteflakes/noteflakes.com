# frozen_string_literal: true

layout = import '_layout/default'

export layout.apply { |**props|
  a('>>>', href: '03', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    markdown <<~MD
      ## What is Papercraft?

      - Ruby DSL for generating HTML
      - Functional approach: templates are procs/lambdas
      - Minimal interface
      - Explicit template arguments
      - Automatic HTML escaping
      - Easily composable: layouts/components
      - Builtin markdown support
      - Built for developer happiness
      - As fast as ERB/ERubi/Herb

      ```ruby
      Greeter = ->(name) {
        h1 "Hello, \#{name}!"
      }

      template = ->(name) {
        div { Greeter(name) }
      }
      template.render('Euruko')
      #=> "<div><h1>Hello, Euruko!</h1></div>"
      ```
    MD


  }
}
