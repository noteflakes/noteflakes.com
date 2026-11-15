# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-04', '1-05', '1-06')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### The functional style

        - A lambda is a package of code
        - On the inside, it's the same as a method
        - On the outside, it's an expression, a value!
        
        ### Code as data!
      MD
    }
  }
}
