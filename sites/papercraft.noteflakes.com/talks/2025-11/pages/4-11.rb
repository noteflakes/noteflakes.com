# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-10', '4-11', '4-12')

  h3 'So how fast is it?'

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```ruby
        tmpl = ->(foo, bar) {
          div {
            h1 foo
            h2 bar
          }
        }
        ```
      MD
    }
    div {
      markdown <<~MD
        ```erb

        <div>
          <h1><%= ERB::Escape.html_escape(foo) %></h1>
          <p><%= ERB::Escape.html_escape(bar) %></p>
        </div>

        ```
      MD
    }
  }

  cols(class: 'one') {
    div {
      markdown <<~MD
        ```
        ruby 3.5.0preview1 (2025-04-18 master d06ec25be4) +YJIT +PRISM [x86_64-linux]
        ...
        Calculating -------------------------------------
                   erb  5.778M (± 1.2%) i/s  (173.06 ns/i) - 29.359M in   5.081629s
            papercraft  5.193M (± 1.4%) i/s  (192.56 ns/i) - 26.274M in   5.060201s
          
        Comparison:
                 erb:  5778230.0 i/s
          papercraft:  5193233.9 i/s - 1.11x  slower
        ```

        ### From 3x slower to only 1.1x! 🙂
        
        - Performance difference has to do with some indirection + exception handling
          in `Papercraft.html`.
      MD
    }
  }
}
