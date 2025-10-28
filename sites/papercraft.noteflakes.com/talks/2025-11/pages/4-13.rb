# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-12', '4-13', nil)

  cols(class: 'three-two') {
    div {
      markdown <<~MD
        ### Conclusion

        - Papercraft makes HTML fun to write, easy to read
        - DSLs are about expressiveness
        - The functional style: structure, testing, reusability
        - Performance matters:
          - We want developer happiness
          - We also want machine happiness

        ### papercraft.noteflakes.com
      MD
    }
    div {
      img(class: 'qr', src: "../assets/qr-noteflakes.com.png")
    }

  }
}
