# frozen_string_literal: true

layout = import '_layout/default'

export layout.apply { |**props|
  a('>>>', href: '06', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    markdown <<~Markdown
      ## Easy layouts

      ```ruby
      layout = ->(**props) {
        html5 {
          head {
            title(props[:title])
          }
          body {
            container {
              render_children(**props)
            }
          }
        }
      }

      page = layout.apply(title: 'Foo') {
        h1 'Bar'
      }
      ```

    Markdown
  }
}
