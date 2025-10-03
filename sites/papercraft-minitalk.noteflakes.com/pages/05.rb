# frozen_string_literal: true

layout = import '_layout/default'

export layout.apply { |**props|
  a('<<<', href: '04', class: 'prev')
  a('>>>', href: '06', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    markdown <<~Markdown
      ## Easy layouts

      ```ruby
      default_layout = ->(**props) {
        html {
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

      article_layout = default_layout.apply { |**props|
        article {
          h1 props[:title]
          markdown props[:md]
        }
      }

      article_layout.render(**article)
      ```

    Markdown
  }
}
