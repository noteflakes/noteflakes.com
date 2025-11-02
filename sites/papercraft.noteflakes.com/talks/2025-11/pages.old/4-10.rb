# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-09', '4-10', '4-11')

  h3 'Putting it all together:'

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```ruby
        # source
        tmpl = ->(foo, bar) {
          div {
            h1 foo
            h2 bar
          }
        }

        Papercraft.compiled_code(tmpl)

        ```
      MD
    }

    div {
      markdown <<~MD
        ```ruby
        # compiled:
        ->(__buffer__, foo, bar) {
          __buffer__
            .<<("<div><h1>")
            .<<(ERB::Escape.html_escape((foo)))
            .<<("</h1><h2>")
            .<<(ERB::Escape.html_escape((bar)))
            .<<("</h2></div>")
          __buffer__
        }
        ```
      MD
    }
  }

  cols(class: 'one') {
    div {
      markdown <<~MD
        ```ruby
        # compilation is automatic:
        Papercraft.html(tmpl, 'FOO', 'BAR')
        #=> "<div><h1>FOO</h1><h2>BAR</h2></div>"
        ```
      MD
    }

  }
}
