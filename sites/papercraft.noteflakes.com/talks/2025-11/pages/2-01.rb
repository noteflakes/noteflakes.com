# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-06', '2-01', '2-02')

  chapter {
    h1 "Chapter 2"
    h2 "Building DSLs in Ruby"
  }
}
