# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('0-03', '1-01', '1-02')

  h3 'Papercraft - functional HTML templates for Ruby'

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```ruby
        Greeter = ->(name) {
          h1 "Hello, \#{name}!"
        }
        template = -> {
          div { Greeter('Paris.rb') }
        }

        Papercraft.html(template)
        #=> "<div><h1>Hello, Paris.rb!</h1></div>"
        ```
      MD

    }
    div {
      markdown <<~MD
        - Write HTML using Ruby
        - Templates as lambdas

        **Design goals**:

        - Developer happiness
        - Functional approach: templates as pure functions
        - Explicit arguments
        - Template composition
      MD

    }
  }
}
