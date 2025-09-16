# frozen_string_literal: true

layout = import '_layout/default'

export layout.apply { |**props|
  a('<<<', href: '06', class: 'prev')
  a('>>>', href: '08', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    markdown <<~Markdown
      ## Markdown support

      Papercraft has *builtin* markdown rendering:

      ```ruby
      -> {
        markdown <<~MD
          Papercraft has *builtin* markdown rendering:

          ```ruby
          -> {
            markdown <<~MD
              Papercraft has *builtin* markdown rendering:
              ...
            MD
          }
          ```
        MD
      }
      ```
    Markdown
  }
}
