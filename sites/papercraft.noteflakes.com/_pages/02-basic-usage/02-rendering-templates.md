---
title: Rendering Templates
---

To render a template, use `Papercraft.html` and pass in the template:

```ruby
Hello = -> { h1 "Hello" }
Papercraft.html(Hello)
#=> "<h1>Hello</h1>"
```

Alternatively you can also render HTML inline by passing a template as a block:

```ruby
Papercraft.html {
  h1 "Hello"
}
#=> "<h1>Hello</h1>"
```

## Passing Parameters

When a template takes one or more arguments, you should pass the corresponding
parameters along with the template:

```ruby
Hello = ->(name) { h1 "Hello, #{name}!" }
Papercraft.html(Hello, "world") #=> "<h1>Hello, world!</h1>"
```

As with any normal Ruby method call, you can pass rest parameters and keyword
parameters to `Papercraft.html`, and they will be passed to the template:

```ruby
Hello = ->(name) { h1 "Hello, #{name}!" }

def render_hello(*args)
  Papercraft.html(Hello, *args)
end

render_hello("world") #=> "<h1>Hello, world!</h1>"
```

## Passing a Block

`Papercraft.html` can also be given a block, which will be passed to the
template. Such a block can be used for rendering inner elements inside the
template. To render the passed block, the template should call `render_children`
or `render_yield`:

```ruby
DivWrapper = -> {
  div { render_yield }
}

Papercraft.html(DivWrapper) { h1 "Hello!" }
#=> "<div><h1>Hello!</h1></div>"
```

> The difference between `render_yield` and `render_children` is that
> `render_yield` will raise an exception if no block is given when rendering.

## Creating Derived Templates with Parameter Application

One of the advantages of expressing templates as lambdas is that you can create derivative templates very easily by applying parameters to an existing template using the `#apply` method:

```ruby
# original template:
Hello = ->(name) { h1 "Hello, #{name}!" }
Papercraft.html(Hello, "world")
#=> "<h1>Hello, world!</h1>"

# derived template:
HelloWorld = Papercraft.apply(Hello, "world")
Papercraft.html(HelloWorld)
#=> "<h1>Hello, world!</h1>"
```

## Rendering XML templates

Papercraft also has experimental support for rendering XML templates, for
example RSS feeds. To render a template as XML, use `Papercraft.xml`:

```ruby
rss_feed = ->() {
  rss(version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom') {
    channel {
      title 'My blog'
      link 'https://myblog.com/'
      description 'My blog'
      language 'en-us'
      pubDate Time.now.httpdate
      ...
    }
  }
}
Papercraft.xml(rss_feed)
```

## Cached rendering of templates

Papercraft also provides a mechanism for caching rendered templates, using
`Papercraft.cache_html`. This method takes an additional parameter used as cache
key. It is the responsibility of the caller to provide a cache key:

```ruby
Papercraft.cache_html(template, cache_key, ...)
```
