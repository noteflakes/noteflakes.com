# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('2-01', '2-02', '2-03')

  h3 "Domain Specific Language"

  markdown <<~MD
    > A Domain-Specific Language (DSL) is a computer language that's targeted to a
    > particular kind of problem, rather than a general purpose language that's
    > aimed at any kind of software problem. (Martin Fowler)

    - DSLs are everywhere: HTML, CSS, YAML etc.
    - In Ruby, they're ubiquitous: Rails, RSpec, Rakefile, Gemfile etc.
    - Metaprogramming: related but not the same.
    - Multiple techniques.
  MD

}
