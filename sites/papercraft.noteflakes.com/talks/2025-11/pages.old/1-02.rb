# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-01', '1-02', '1-03')

  h3 "Lambdas"

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```ruby
        -> (x, y) { x + Y } #=> <Proc:...>

        -> (x, y) { x + y }.(3, 4) #=> 7

        # also:
        -> (x, y) { x + y }.call(3, 4)
        -> (x, y) { x + y }[3, 4]
        ```
      MD
    }

    div {
      markdown <<~MD
        - A lambda is a `Proc`
        - Anonymous expression
        - A "callable"
        - Slightly different semantics compared to non-lambda Procs
        - Takes arguments just like a regular method
      MD
    }
  }
    
}
