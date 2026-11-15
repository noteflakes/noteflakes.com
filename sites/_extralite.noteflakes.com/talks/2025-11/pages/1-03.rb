# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-02', '1-03', '1-04')

  h3 'Papercraft: Layouts'

  cols(class: 'one-one') {
    div {
      markdown <<~MD
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

        ...
        Papercraft.html(default_layout) {
          h1 'foo'
        }
        ```
      MD
    }
    div {
      markdown <<~MD
        ```ruby
        article_layout =
          Papercraft.apply(default_layout) { |**a|
            article {
              h1 a[:title]
              markdown a[:md]
            }
          }

        ...
        Papercraft.html(article_layout, **article)
        ```
      MD
    }
  }
}
