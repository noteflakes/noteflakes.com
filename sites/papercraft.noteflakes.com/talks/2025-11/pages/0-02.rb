# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('0-01', '0-03')

  cols(class: 'two-three') {
    div {
      markdown <<~MD
        ### Noteflakes
        
        - Independent software company
        - Bourgogne, France
        - ~20 years experience
        - Industrial process control
        - Infrastructure facilities
        - "Digital plumbing"
        - Ruby, C/C++, JS, PHP, Go & more
      MD
    }
    
    div {
      img(class: 'fit', src: "../assets/map.png")
    }
  }
}
