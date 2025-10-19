---
title: Component Templates
---

Component templates are templates used for generating HTML for certain parts of
the page that may be repeated many times, each time with different dynamic data.
That way, you don't need to repeat the markup itself, but only make calls the
component in your main template. Components can also be arbitrarily nested,
which means that you break your page markup into small pieces, and *compose*
them together to create bigger and bigger parts of your page.

Since Papercraft components take explicit arguments, they can be thought of as
*pure functions*, which means that they can be safely used in any context and
any situation.

By convention, Papercraft component templates are assigned to constants, which
makes it easy to use them in your templates. Let's examine a basic component:

```ruby
Greet = ->(name) {
  h1 "Hello, #{name}!"
}
```

As you can see, the `Greet` component is just a regular Papercraft template. We
can then use this component by making calls to `Greet()` inside our main
template:

```ruby
Papercraft.html {
  div {
    Greet("foo")
    Greet("bar")
  }
}
#=> "<div><h1>Hello, foo!</h1><h1>Hello, bar!</h1></div>"
```

## Components as Arguments

You can also inject arbitrary components into another template (be it a whole
page template or a component template) by passing them as parameters. You can
render a component given as an argument by passing it to the `render` method. Any additional parameters are passed to the component:

```ruby
DivGreet = ->(greet, name) {
  div {
    render greet, name
  }
}

Papercraft.html(DivGreet, Greet, "world")
#=> "<div><h1>Hello, world!</h1></div>"
```

## Components Passed as Block

Another way to use a component is by passing it as a block. This is done in
conjunction with `render_yield` or `render_children`:

```ruby
DivWrapper = ->(*args) {
  div {
    render_children *args
  }
}

Papercraft.html(DivWrapper, &Greet)
```

## Organizing Component Templates

Papercraft gives you the freedom to organize your templates as you wish, but a
good way to this is to put your component templates in modules. Here's an
example:

```ruby
module WebComponents
  Table = ->(cols, rows) {
    table {
      thead {
        tr { cols.each { th it } }
      }
      tbody {
        rows.each { |row|
          tr { row.each { td it } }
        }
      }
    }
  }

  Card = ->(title:) {
    card {
      h2 title
      render_children
    }
  }
end

Papercraft.html(WebComponents::Card, "My card") {
  WebComponents::Table(cols, rows)
}
```
