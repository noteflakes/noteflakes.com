# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-07', '4-08', '4-09')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### Converting AST to source code
        
        - Not included in Prism
        - Traverse tree, emit code for each node
        - `sirop` gem: get AST, convert back to source

        ```ruby
        class Papercraft::Compiler < Sirop::Sourcifier
          # simplified version
          def visit_tag_node(node)
            @html_parts <<
              format_html_tag_open(node.tag, node.attributes)
          
            if node.block
              visit(node.block.body)
            elsif (inner_text = node.inner_text)
              @html_parts << interpolated(
                "ERB::Escape.html_escape(\\\#{format_code(inner_text)})"
              )
            end
            @html_parts << format_html_tag_close(node.tag)
          end

          def emit_code(loc)
            flush_html_parts
            super(loc)
          end
        end
        ```
      MD
    }
  }
}
