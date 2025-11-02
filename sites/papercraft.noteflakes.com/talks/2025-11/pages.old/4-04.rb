# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-03', '4-04', '4-05')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### Prism - the new Ruby parser
        
        - Before Prism: multiple parsers: inconsistent parsing, different
          runtimes, different Ruby versions, different AST classes, different
          APIs...
        - Prism: new parser used by CRuby, JRuby, TruffleRuby, WASM engines
        - AST: Node types, named fields, location information
        - C API, Ruby API
        - Uses: static analysis, formatting, linting, **source code transformation**
      MD
    }
  }
}
