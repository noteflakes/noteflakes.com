# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-11', '1-12', '1-13')

  h3 'Pure functions'

  cols(class: 'one') {
    markdown <<~MD
      - Always same return value for same arguments.
      - No side effects.
    MD
  }
  cols(class: 'one-one') {
    div {
      markdown <<~MD
        ```ruby
        # This is a pure function.
        ->(foo, bar) {
          div {
            h1 foo
            p bar
          }
        }
        ```
          
        ```ruby
        # This is not a pure function.
        -> {
          div {
            h1 "The time is:"
            p Time.now.to_s
          }
        }
        ```
      MD
    }
    div {
      markdown <<~MD
        ```ruby
        # This is not a pure function.
        ->(id) {
          user = DB.query(
            "select * from users where id = ?", id
          ).first

          h2 "User name: \#{user[:name]}"
        }
        ```

        ```ruby
        # This is not a pure function.
        -> {
          LOGFILE.info("Rendering my awesome template...")
          h2 "Oops, I just caused a side effect"
        }

        ```
      MD
    }
  }
}
