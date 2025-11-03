# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-07', '1-08', '1-09')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### AST Mutation
        
        - Visitor pattern for traversing AST
        - `Prism::MutationCompiler` used for mutating AST
        
        ```ruby
        class TagTranslator < Prism::MutationCompiler
          # simplified excerpt
          def visit_call_node(node, dont_translate: false)
            match_tag(node) || super(node)
          end

          def match_tag(node)
            return if node.receiver
          
            Papercraft::TagNode.new(node)
          end
        end
        ```
      MD
    }
  }
}
