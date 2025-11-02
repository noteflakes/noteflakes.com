# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-02', '1-03', '1-04')

  cols(class: 'three-two') {
    div {
      markdown <<~MD
        ### Lambda calculus
        
        - **Alonzo Church** ~1936
        - Function abstraction & application
        - Variable binding & substitution
        - No "data", just functions
        - Turing complete

        ```html
        λx.λf.f x
        ```

        ```ruby
        -> x { -> f { f.(x) } }
          .(3).(->(x) { x + 1 }) #=> 4
        ```
      MD
    }

    div {
      h5 "Programming with nothing"
      p "FizzBuzz algorithm implemented in lambda calculus (in Ruby)"

      img(class: "qr-med", src: "../assets/qr-fizzbuzz.png")
    }
  }
    
}
