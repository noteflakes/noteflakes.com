# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('5-01', '5-02', '5-03')

  chapter {
    h1 "Chapter 5"
    h2 "Conclusion"
  }
}
