# frozen_string_literal: true

layout = import '/_layout/default'

export layout.apply { |**props|
  a('<<<', href: '01', class: 'prev')
  a('>>>', href: '04', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    markdown <<~MD
      ## What is Papercraft?

      - Write HTML using Ruby
      - Functional templates: it's just procs/lambdas
      - No boilerplate

      ```ruby
      Greeter = ->(name) {
        h1 "Hello, \#{name}!"
      }

      template = -> {
        div { Greeter('Euruko') }
      }
      Papercraft.html(template)
      #=> "<div><h1>Hello, Euruko!</h1></div>"
      ```

      - Explicit template arguments
      - Automatic HTML escaping
      - Easily composable: layouts/components
      - Builtin markdown support
      - Designed for developer happiness
      - As fast as ERB/ERubi/Herb
    MD
  }
}
