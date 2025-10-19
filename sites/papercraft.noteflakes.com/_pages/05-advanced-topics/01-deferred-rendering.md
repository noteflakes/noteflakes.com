---
title: Deferred Rendering
---

Deferred rendering allows you to insert pieces of markup into a template based
on data that might be supplied later, perhaps by a component template or by some
inner markup in a block passed to the template. One use of this technique is to
allow components to add script sources to a page. Deferred rendering is done by
calling `defer`:

```ruby
Layout = ->(**props) {
  html {
    head {
      defer {
        props[:style_urls]&.each_key {
          link(rel: "stylesheet", type: "text/css",  href: it)
        }
      }
    }
    body {
      render_children(**props)
    }
  }
}

SpecialButton = ->(id:, text:, **props) {
  (props[:style_urls] ||= {})['/assets/button_style.css'] = true
  button(text, id:)
}

Papercraft.html(Layout) { |**props|
  div {
    SpecialButton(id: 'button1', text: 'Click here', **props)
  }
}
```
