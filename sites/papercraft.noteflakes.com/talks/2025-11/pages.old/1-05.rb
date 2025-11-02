# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-04', '1-05', '1-06')

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ### Pure functions

        - Same output for same input(s), and:
        - No side-effects

        - Can be safely used in any context
        - How to do something useful with pure functions?
        - Functional core / imperative shell
      MD
    }

    div {
      markdown <<~MD
        ### Higher-order functions
        
        - Take a function as argument, or:
        - Return a function

        - Build abstractions
        - Composition instead of inheritance
        - Dependency injection
      MD
    }
  }
}
