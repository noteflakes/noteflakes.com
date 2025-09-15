# frozen_string_literal: true

layout = import '_layout/default'

export layout.apply { |**props|
  a('>>>', href: '07', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    markdown <<~Markdown
      ## Easy components

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
        Table(
          ['Title', 'Location'],
          [ ['RailsWorld', 'Amsterdam'],
            ['Friendly.rb', 'Bucarest'],
            ['Euruko', 'Viana do Castelo'] ]
        )
      }
      ```
    Markdown
  }
}
