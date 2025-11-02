# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('3-06', '3-07', '3-08')

    h3 'The Papercraft DSL - naive implementation'

    cols(class: 'one') {
    div {
      markdown <<~MD
        ```
        ruby 3.5.0preview1 (2025-04-18 master d06ec25be4) +YJIT +PRISM [x86_64-linux]
        ...
        Calculating -------------------------------------
                 ERB  6.902M (± 1.6%) i/s  (144.88 ns/i) - 35.076M in   5.083022s
                 DSL  2.353M (± 1.3%) i/s  (424.94 ns/i) - 11.866M in   5.043127s

        Comparison:
                 ERB:  6902378.2 i/s
                 DSL:  2353288.4 i/s - 2.93x  slower
        ```
      MD
    }
  }
}
