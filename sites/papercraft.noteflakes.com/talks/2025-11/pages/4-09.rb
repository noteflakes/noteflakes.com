# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-08', '4-09', '4-10')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### Converting AST to source code part 2
        
        ```ruby
        class Papercraft::Compiler < Sirop::Sourcifier
          # simplified version
          def flush_html_parts
            buffer = +''

            @html_parts.each do |(loc, part)|
              if (m = part.match(/^#\{(.+)\}$/m))
                # interpolated part
                emit_html_buffer_push(buffer, quotes: true) if !buffer.empty?
                emit_html_buffer_push(m[1])
              else
                buffer << part
              end
            end

            emit_html_buffer_push(buffer, quotes: true) if !buffer.empty?
            @html_parts.clear
          end
        
          def emit_html_buffer_push(part, quotes: false)
            q = quotes ? '"' : ''
            emit(".<<(\#{q}\#{part}\#{q})")
            part.clear
          end
        end
        ```
      MD
    }
  }
}
