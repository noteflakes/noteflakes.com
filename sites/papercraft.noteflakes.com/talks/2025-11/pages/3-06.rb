# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('3-05', '3-06', '3-07')

    h3 'The Papercraft DSL - naive implementation'

    cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```ruby
        template = -> {
          div {
            h1 'foo'
            p 'bar'
          }
        }

        Renderer.new.render(template)
        #=> "<div>...</div>"
        ```
      MD
    }
    div {
      markdown <<~MD
        ```ruby
        class Renderer
          def render(template)
            @buffer = +''
            instance_eval(template)
            @buffer
          end

          def div(&block)
            @buffer << '<div>'
            instance_eval(block)
            @buffer << '</div>' 
          end

          def h1(inner_text)
            @buffer << "<h1>\#{inner_text}</h1>"
          end

          def p(inner_text)
            @buffer << "<p>\#{inner_text}</p>"
          end
        end
        ```
      MD
    }
  }
}
