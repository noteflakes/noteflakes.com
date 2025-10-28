# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('3-07', '3-08', '4-01')

    h3 'Why so slow?'

    cols(class: 'one-one') {
    div {
      markdown <<~MD
        #### DSL

        ```ruby
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

        @buffer = +''
        instance_eval {
          div {
            h1 'foo'
            p 'bar'
          }
        }
        @buffer
        ```
      MD
    }
    div {
      markdown <<~MD
        #### ERB

        ```html
        <div>
          <h1><%= 'foo' %></h1>
          <p><%= 'bar' %></p>
        </div>
        ```

        ```ruby
        # Compiled template code:
        _erbout = +''; _erbout.<< "<div><h1>"
        _erbout.<<(( 'foo' ).to_s); _erbout.<< "</h1><p>"
        _erbout.<<(( 'bar' ).to_s); _erbout.<< "</p></div>"
        _erbout
        ```

        - HTML Tags are coalesced
        - No method calls (for tags)
        - `instance_eval` is really slow! (~2.65x slower than #call)
      MD
    }
  }
}
