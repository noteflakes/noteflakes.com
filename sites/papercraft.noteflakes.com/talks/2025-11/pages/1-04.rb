# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-03', '1-04', '1-05')

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ### Functional
        
        ```ruby
        Adder = -> (x, y) { x + y }
        Adder.(3, 4) #=> 7
        ```
      
        - less code, less boilerplate
        - Single interface / single responsibility
        - Code packaged in an expression
        - Encapsulation: Closure
        - Inheritance: Composition
        - Dependency injection: Higher-order functions
      MD
    }

    div {
      markdown <<~MD
        ### Object-oriented
        
        ```ruby
        class Calculator
          def initialize
          end

          def add(x, y)
            x + y
          end
        end

        calculator = Calculator.new
        calculator.add(3, 4) #=> 7
        ```
      MD
    }
  }
    
}
