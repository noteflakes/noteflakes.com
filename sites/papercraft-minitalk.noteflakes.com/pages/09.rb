# frozen_string_literal: true

layout = import '_layout/default'

export layout.apply { |**props|
  a('>>>', href: '10', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    markdown <<~Markdown
      ## Papercraft: Summary
      
      - Fun to write, easy to read
      - Stay in the zone: it's just Ruby!
      - Easy layouts and components
      - Builtin markdown support
      - As fast as ERB/ERubi/Herb
      - Coming soon: template debugging tools!
    Markdown

    hr
    h2 'github.com/digital-fabric/papercraft'
  }
}
