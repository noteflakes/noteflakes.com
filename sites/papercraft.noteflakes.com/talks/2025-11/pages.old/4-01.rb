# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('3-08', '4-01', '4-02')

  chapter {
    h1 "Chapter 4"
    h2 "Solving the DSL performance gap"
  }
}
