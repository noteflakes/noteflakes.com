# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-04', '1-05', '1-06')

  h3 'The functional style'

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        - A lambda is a package of code
        - On the inside, it's the same as a method
        - On the outside, it's just an expression, a value!
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
