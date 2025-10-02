---
title: Built-in Methods
---

## `markdown` - Render Markdown

Papercraft includes builtin support for rendering markdown documents or
snippets. To render markdown in a template, use the `markdown` method:

```ruby
-> {
  div {
    markdown <<~MD
      # Hello, world!
    MD
  }
}.render
#=> "<div><h1>Hello, world!</h1></div>"
```

## `raw` - Render Raw HTML

If you want to include a piece of raw HTML in your templates, use the `raw`
method call:

```ruby
-> {
  div { raw "<p>Hi</p>" }
}.render
#=> "<div><p>Hi</p></div>"
```

## `tag` - Custom Tags

The `tag` method can be used to dynamically create HTML tags. It is useful for
creating parametric tags (i.e. when the tag name is a dynamic value). The `tag`
method is similar to normal tag method calls, expect it takes an additional tag
name parameter as its first argument:

```ruby
-> {
  tag "p", "Hi", id: "hi"
}.render
#=> "<p id=\"hi\">Hi</p>"
```

## `text` - Render Inline Text

The `text` method is used for emitting inline escaped text:

```ruby
-> {
  p {
    text "foo"
    br
    text "bar"
  }
}.render
#=> "<p>foo<br>bar</p>"
```
