# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-05', '4-06', '4-07')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### Template source:
        
        ```ruby
        -> { h1 'foo' }
        ```
      

        ### AST:
        
        ```
        ...
        @ StatementsNode (location: (3,9)-(3,17))
        └── body: (length: 1)
            └── @ CallNode (location: (3,9)-(3,17))
                ├── receiver: ∅
                ├── name: :h1
                └── arguments:
                    @ ArgumentsNode (location: (3,12)-(3,17))
                    └── arguments: (length: 1)
                        └── @ StringNode (location: (3,12)-(3,17))
                            └── unescaped: "foo"
        ```
      MD
    }
  }
}
