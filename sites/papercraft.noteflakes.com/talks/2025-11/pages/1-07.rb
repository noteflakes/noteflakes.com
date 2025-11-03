# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-06', '1-07', '1-08')

  h3 'Converting Source code into AST'

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```
        -> (foo, bar) {


          
        
          div {


            
          
            
          
          
            h1 foo






            
            p bar
          }
        }
        ```
      MD
    }
    div {
      markdown <<~MD
        ```
        @ LambdaNode (location: (7,4)-(12,9))
        ├ parameters...
        └ body:
          @ StatementsNode (location: (8,10)-(11,11))
          └ body: (length: 1)
            └ @ CallNode (location: (8,10)-(11,11))
              ├ receiver: ∅
              ├ name: :div
              └ block:
                @ BlockNode (location: (8,14)-(11,11))
                └ body:
                  @ StatementsNode (location: (9,12)-(10,17))
                  └ body: (length: 2)
                    ├ @ CallNode (location: (9,12)-(9,18))
                    │ ├ receiver: ∅
                    │ ├ name: :h1
                    │ └ arguments:
                    │   @ ArgumentsNode (location: (9,15)-(9,18))
                    │   └ arguments: (length: 1)
                    │     └ @ LocalVariableReadNode (location: ...)
                    │       └ name: :foo
                    └ @ CallNode ...


        ```
      MD
    }
  }
}
