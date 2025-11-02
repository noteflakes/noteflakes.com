# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-02', '4-03', '4-04')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### The basic idea:
        
        1. Get template source code
        2. Parse source code to AST
        3. Mutate AST
        4. Convert mutated AST to source code
      MD
    }
  }
}
