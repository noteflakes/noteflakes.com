# frozen_string_literal: true

layout = import '/_layout/default'

export layout.apply { |**props|
  a('<<<', href: '02', class: 'prev')
  a('>>>', href: '05', class: 'next')

  div(class: 'centered') {
    img class: 'logo', src: '/assets/papercraft.png'

    h2 'Beautiful template logic'
  }
  div(class: 'split') {
    div {
      markdown <<~MD
        ## Papercraft
      
        ```ruby
        ->(show_books, books) {
          if show_books
            ul {
              books.each {
                li {
                  a it.title,
                    href: it.href
                }
              }
            }
          end
        }
        ```
      MD
    }
    div {
      markdown <<~MD
        ## ERB/Erubi
        
        ```html
        
        <% if @show_books %>
        <ul>
          <% @books.each do %>
            <li>
              <a href="<%= it.href %>">
                <%= it.title %>
              </a>
            </li>
          <% end %>
        </ul>
        <% end %>
        ```
      MD
    }
  }
}
