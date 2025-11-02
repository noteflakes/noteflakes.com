# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('2-04', '2-05', '3-01')

  h3 "But what about metaprogramming?"

  cols(class: 'one-one') {
    div {
      markdown <<~MD
        Uses: 

        - Modifying default behavior.
        - Extending behavior: callbacks, additional methods.
        - **Optimizing performance**.

        - Not only runtime, but also source code analysis, testing, devops, sysops
      MD
    }

    div {
      markdown <<~MD
      MD
    }
  }
}
