---
title: Rendering Templates
---

To render a template, simply call the `#render` method on the template:

```ruby
Hello = -> { h1 "Hello" }
Hello.render
#=> "<h1>Hello</h1>"
```

## Passing Parameters

When a template takes one or more arguments, you should pass the corresponding
parameters to `#render`:

```ruby
Hello = ->(name) { h1 "Hello, #{name}!" }
Hello.render("world") #=> "<h1>Hello, world!</h1>"
```

As with any normal Ruby method call, you can pass rest parameters and keyword
parameters to `#render`, and they will be passed to the template:

```ruby
Hello = ->(name) { h1 "Hello, #{name}!" }

def render_hello(*args)
  Hello.render(*args)
end

render_hello("world") #=> "<h1>Hello, world!</h1>"
```

## Passing a Block

The `#render` method can also be given a block, which will be passed to the
template. Such a block can be used for rendering inner elements inside the
template. To render the passed block, the template should call `render_children`
or `render_yield`:

```ruby
DivWrapper = -> {
  div { render_yield }
}

DivWrapper.render { h1 "Hello!" }
#=> "<div><h1>Hello!</h1></div>"
```

> The difference between `render_yield` and `render_children` is that
> `render_yield` will raise an exception if no block is given when rendering.

## Creating Derived Templates with Parameter Application

One of the advantages of expressing templates as lambdas is that you can create derivative templates very easily by applying parameters to an existing template using the `#apply` method:

```ruby
# original template:
Hello = ->(name) { h1 "Hello, #{name}!" }
Hello.render("world")
#=> "<h1>Hello, world!</h1>"

# derived template:
HelloWorld = Hello.apply("world")
HelloWorld.render
#=> "<h1>Hello, world!</h1>"
```
