# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-11', '4-12', '4-13')

  cols(class: 'one') {
    markdown <<~MD
      ### Papercraft - future work
      
      - Inlining: optimize complex templates
      - Improved exception handling
      - Integration: Rails, other web frameworks?
      - Template debugging tools in the browser!
    MD
  }
}
