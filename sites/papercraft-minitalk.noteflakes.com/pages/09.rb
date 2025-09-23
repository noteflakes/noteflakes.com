# frozen_string_literal: true

layout = import '_layout/default'

export layout.apply { |**props|
  a('<<<', href: '08', class: 'prev')
  a('>>>', href: '10', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    markdown <<~MD
      ## Papercraft: Summary
      
      - Fun to write, easy to read
      - Stay in the zone: it's just Ruby!
      - Easy layouts and components
      - Builtin markdown support
      - As fast as compiled ERB/ERubi/HERB
      - Coming soon: template debugging tools in the browser!
    MD

    hr
    h2 'github.com/digital-fabric/papercraft'

    p "(P.S. This presentation was made with Papercraft!)"
  }
}
