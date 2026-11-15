# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-12', '1-13', '1-14')

  h3 'Papercraft: summary'

  cols(class: 'two-one') {
    div {
    markdown <<~MD
      - Innovative: functional approach, compiled templates.
      - developer happiness + machine happiness.
      - Composable: easy layouts and components.
      - Builtin markdown support.
      - As fast as ERB.
      - Future work: inlining, template debugging tools.
      - More future work: DSL + tools for generating code!

      #### [papercraft.noteflakes.com](https://papercraft.noteflakes.com/)
      #### [github.com/digital-fabric/papercraft](https://github.com/digital-fabric/papercraft)
    MD
    }
    div {
      img(class: 'qr', src: "../assets/qr-noteflakes.com.png")
    }
  }
}
