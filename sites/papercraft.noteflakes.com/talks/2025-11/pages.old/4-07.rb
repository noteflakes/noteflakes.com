# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-06', '4-07', '4-08')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### AST Mutation
        
        - Visitor pattern for traversing AST
        - `Prism::MutationCompiler` used for mutating AST
        
        ```ruby
        # simplified excerpt
        class TagTranslator < Prism::MutationCompiler
          def visit_call_node(node, dont_translate: false)
            match_tag(node) || super(node)
          end

          def match_tag(node)
            return if node.receiver
          
            Papercraft::TagNode.new(node)
          end
        end
        ```

        ```
        @ CallNode (location: (3,9)-(3,17))
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
