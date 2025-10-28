# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-11', '4-12', '4-13')

  cols(class: 'one') {
    markdown <<~MD
      ### Lessons
      
      - Ruby is about developer happiness
      - Because of its expressiveness
      - DSLs are a big part of that
      
    MD
  }
}
