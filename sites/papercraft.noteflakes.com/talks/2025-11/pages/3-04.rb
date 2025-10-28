# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('3-03', '3-04', '3-05')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### Layouts in Papercraft

        ```ruby
        default_layout = ->(**props) {
          html(lang: 'en') {
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

        article_layout = Papercraft.apply(default_layout) { |**props|
          article {
            h1 props[:title]
            markdown props[:md]
          }
        }

        Papercraft.html(article_layout, **article)
        ```
      MD
    }
  }
}
