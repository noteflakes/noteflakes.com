# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('1-07', '1-08', '1-09')

  h3 "Papercraft vs. ERB"

  cols(class: 'one') {
    div(class: 'bigger') {
      markdown <<~MD
        &nbsp;|**Developer**|**Machine**
        ---|:---:|:---:
        **ERB**|☹️|🙂
        **Papercraft**|🙂|☹️
      MD
    }
  }
  cols(class: 'one-one') {
    div {
      markdown <<~MD
        #### Source:

        ```ruby
        ->(foo, bar) {
          div {
            h1 foo
            p bar
          }
        }
          
        ```    
      MD
    }
    div {
      markdown <<~MD
        #### Ideally:
        
        ```ruby
        ->(__buffer__, foo, bar) {
          __buffer__ << '<div><h1>'
          __buffer__ << ERB::Escape.html_escape(foo)
          __buffer__ << '</h1><p>'
          __buffer__ << ERB::Escape.html_escape(bar)
          __buffer__ << '</p></div>'
        }
        ```
      MD
    }
  }}
