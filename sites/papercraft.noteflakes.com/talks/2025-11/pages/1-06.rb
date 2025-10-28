# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-05', '1-06', '2-01')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### Functional architecture

        - Rethink the structure of our programs
        - Can we apply **SOLID** priniciples?
          - Single responsibility
          - Extend using composition: small, reusable pieces
          - Liskov substitution: uniform interface + composition
          - Inversion of control / dependency injection with higher-order functions
          - 
        - Not necessarily limited to lambdas
          - Class design adhering to **SOLID**
        - Rack: example of functional interface
        - Discipline: design each functionality separately
      MD
    }
  }
}
