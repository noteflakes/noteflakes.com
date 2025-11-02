# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('3-01', '3-02', '3-03')

  markdown <<~MD
    ### What is Papercraft?

    - Write HTML using Ruby
    - Templates as lambdas

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

    **Design goals**:

    - Developer happiness
    - Functional approach: templates as pure functions
    - Explicit arguments
    - Template composition
  MD
}
