# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('2-05', '3-01', '3-02')

  chapter {
    h1 "Chapter 3"
    h2 "Papercraft: functional HTML templating"
  }
}
