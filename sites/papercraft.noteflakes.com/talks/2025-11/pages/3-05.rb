# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('3-04', '3-05', '3-06')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### Components in Papercraft

        ```ruby
        Table = ->(cols, rows) {
          table {
            thead {
              tr { cols.each { th it } }
            }
            tbody {
              rows.each { |row|
                tr { row.each { td it } }
              }
            }
          }
        }
  
        -> {
          div {
            Table(
                ['Title',       'Location'],
              [ ['RailsWorld',  'Amsterdam'],
                ['Friendly.rb', 'Bucharest'],
                ['Euruko',      'Viana do Castelo'] ]
            )
          }
        }
        ```
      MD
    }
  }
}
