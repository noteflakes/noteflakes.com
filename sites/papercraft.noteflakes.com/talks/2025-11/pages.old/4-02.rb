# frozen_string_literal: true

layout = import '../_layout/default'
Nav = import '../_components/nav'

export layout.apply { |**props|
  Nav('4-01', '4-02', '4-03')

  cols(class: 'one') {
    div {
      markdown <<~MD
        ### Quick Recap: Papercraft vs. ERB

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
  }
}
