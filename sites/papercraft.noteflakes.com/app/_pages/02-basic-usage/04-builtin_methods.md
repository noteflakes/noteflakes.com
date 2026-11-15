---
title: Built-in Methods
---

## `link_stylesheet` - Add Stylesheet Link

This is a convenience method for adding a stylesheet link:

```ruby
Papercraft.html {
  link_stylesheet "/assets/print.css", media: "print"
}
#=> "<link rel=\"stylesheet\" href=\"/assets/print.css\" media=\"print\">"
```

## `markdown` - Render Markdown

Papercraft includes builtin support for rendering markdown documents or
snippets. To render markdown in a template, use the `markdown` method:

```ruby
Papercraft.html {
  div {
    markdown <<~MD
      # Hello, world!
    MD
  }
}
#=> "<div><h1>Hello, world!</h1></div>"
```

## `raw` - Render Raw HTML

If you want to include a piece of raw HTML in your templates, use the `raw`
method call:

```ruby
Papercraft.html {
  div { raw "<p>Hi</p>" }
}
#=> "<div><p>Hi</p></div>"
```

## `tag` - Custom Tags

The `tag` method can be used to dynamically create HTML tags. It is useful for
creating parametric tags (i.e. when the tag name is a dynamic value). The `tag`
method is similar to normal tag method calls, expect it takes an additional tag
name parameter as its first argument:

```ruby
Papercraft.html {
  tag "p", "Hi", id: "hi"
}
#=> "<p id=\"hi\">Hi</p>"
```

## `text` - Render Inline Text

The `text` method is used for emitting inline escaped text:

```ruby
Papercraft.html {
  p {
    text "foo"
    br
    text "bar"
  }
}
#=> "<p>foo<br>bar</p>"
```
