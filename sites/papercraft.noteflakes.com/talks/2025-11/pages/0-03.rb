# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('0-02', '1-01')

  cols(class: 'two-three') {
    div {
      markdown <<~MD
        ### My open-source gems
        
        - Extralite: fast(er) SQLite adapter
        - Papercraft: HTML templating
        - Syntropy: web framework (WIP)
        - UringMachine: io_uring for Ruby
        - Sequel: SQL + ORM
        - more...
      MD
    }
    
    div {
      img(class: 'fit', src: "../assets/home.jpg")
    }
  }
}
