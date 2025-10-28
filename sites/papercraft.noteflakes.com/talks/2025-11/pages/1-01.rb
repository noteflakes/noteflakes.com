# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('0-03', '1-01', '1-02')

  chapter {
    h1 "Chapter 1"
    h2 "The functional style in Ruby"
  }
}
