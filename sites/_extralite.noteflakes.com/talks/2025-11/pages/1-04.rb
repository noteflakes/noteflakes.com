# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-03', '1-04', '1-05')

  h3 "Papercraft: Components"
  cols(class: 'one-one') {
    div {
      markdown <<~MD
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
        ```
      MD
    }
    div {
      markdown <<~MD
        ```ruby
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
