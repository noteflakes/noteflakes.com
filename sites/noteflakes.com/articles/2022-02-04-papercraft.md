---
title: Papercraft - Composable Templating for Ruby
layout: article
---

Papercraft is a new Ruby gem I've been working on, that provides a new way to
render HTML, XML and JSON using plain Ruby. Here's what it looks like:

```ruby
require 'papercraft'

template = Papercraft.html {
  html5 {
    head {
      title 'Some title'
    }
    body {
      emit_yield
    }
  }
}

template.render('Page title') { h1 'Hello, world!' }

#=> "<html><head><title>Some title</title></head><body><h1>Hello, world!</h1></body></html>"
```



Of course, a Ruby DSL for constructing HTML, XML or JSON is nothing new. Here's
a list of previous projects that already do that:

- [Arbre](https://github.com/activeadmin/arbre)
- [Erector](https://github.com/erector/erector)
- [Fortitude](https://github.com/ageweke/fortitude)
- [Markaby](https://github.com/markaby/markaby)
- [Jbuilder](https://github.com/rails/jbuilder)

All of the above offer some variation on the same theme: you construct HTML
using nested Ruby blocks, e.g.:

```ruby
html {
  body {
    div {
      p 'foo'
      p 'bar'
    }
  }
}
```

I've been a long time admirer of Ruby procs. To me, procs are perhaps the single
most unique feature of Ruby, especially in their block form:

```ruby
items.sort_by { |item| item.path }.each { |item| do_something_with(item) }
```

When you call a method with a block, you are in injecting a piece of your own
code into some other code, and this lets you compose different pieces of code in
a variety of ways. The way Ruby blocks are integrated into the language is
perhaps the defining feature of Ruby, and to me it's one of the main reasons
Ruby makes developers happy.

I've been playing for a while now with all kinds of ideas for constructing DSLs
using blocks. One project I created a while ago was Rubyoshka, a Ruby gem that
lets you write HTML using plain Ruby syntax. The name was a nod to the
[Matryoshka](https://en.wikipedia.org/wiki/Matryoshka_doll), the Russian nesting
doll.

I've recently came up with a way to make it even better, and have decided to
give this library a new name, henceforth
[Papercraft](https://github.com/digital-fabric/papercraft). Papercraft is unique
in how it embraces Ruby procs, and how it enables developers to express the
different parts of an HTML page (or XML and JSON documents) using procs on one
hand, and to compose those different parts in a variety of ways on the other
hand.

## Explicit template parameters

The most important difference between Papercraft and all of its predecessors is
the fact that in Papercraft, any variables referenced in the template logic
should be passed explicitly to the template when it is rendered:

```ruby
greeter = Papercraft.html { |name:| h1 "Hello, #{name}!" }

greeter.render(name: 'world') #=> "<h1>Hello, world!</h1>"
```

In the above example, we create a template that takes a single named argument,
`name:`. When we want to render the template, we need to supply the a `name:`
parameter, which is then injected by the template code into the resulting HTML.

This way of injecting data into templates offers multiple advantages: the data
flow is much clearer - since you're not implicitly reyling on variables that
just happen to be in your template's binding, and debugging is easier - if you
forget to provide the `name` parameter, Ruby will tell you!

## Template application

Papercraft takes this idea even further by letting you create a derivative
template by applying parameters to the source template, using the `#apply`
method. You can select to do a full or partial application:

```ruby
greeter = Papercraft.html { |greeting:, name:| h1 "#{greeting}, #{name}!" }
goodbyer = greeter.apply(greeting: 'Goodbye')

goodbyer.render(name: 'world') #=> "<h1>Goodbye, world!</h1>"
```

In the above example, we take our `greeter` and make it a bit more general - it
now also takes a `greeting:` argument. We then create a derivative template by
partially applying `greeter` with just the `greeting:` parameter filled in. We
then render the `goodbyer` template, passing in the missing `name:` parameter.

## Block application

The idea of application can be taken further with the use of applied blocks.
Here's how you do derivative layouts in Papercraft:

```ruby
layout = Papercraft.html { |**props|
  html {
    head {
      title props[:title]
    }
    body {
      emit_yield **props
    }
  }
}

article_layout = layout.apply { |title:, markdown_content:|
  article {
    h1 title
    emit_markdown markdown_content
  }
}

article_layout.render(title: 'Foo', markdown_content: '## Bar')
```

In the above example, we first create a layout. This layout creates a generic
HTML structure, with the `body` section containing a call to `emit_yield`, which
expects a block to be injected. This can be done either using `#apply` or
`#render` and passing a block. We then create a derivative layout that applies a
block to be emitted inside the `body` section.

Notice how parameters passed to the `layout` template are explicitly passed
along to the applied block (in the call to `#emit_yield`), and how they are
destructured in the block given to `layout.apply`. Finally, we can render the
`article_layout` to HTML by calling `#render` with the needed parameters.

## Template composition

Using `#emit_yield` is not the only way to pass in arbitrary blocks to a
template. In fact, you can pass any number of template blocks as parameters into
your template, and then use `#emit` to emit them. Here's another way layout
templates can be created with Papercraft:

```ruby
layout = Papercraft.html { |header:, content:, footer:|
  html {
    body {
      emit header
      emit content
      emit footer
    }
  }
}

layout.render(
  header:   -> { header { p 'some header' } },
  content:  -> { content { h1 'Some content' } },
  footer:   -> { footer { p 'some footer' } }
)
```

## Higher order templates

We can create higher order templates by writing methods (or procs) that take a
template as input and return a composed template as output, normally :

```ruby
div_wrap = ->(templ) {
  div {
    emit templ
  }
}

layout = Papercraft.html { |content|
  body {
    emit div_wrap.call(content)
  }
}

layout.render(-> { h1 'hi' })
#=> "<body><div><h1>hi</h1></div></body>"
```

In the above example, we create a higher order template called `div_wrap`. It
takes as an input a given template, and returns as its output a template
wrapping the original template with a `div` element.

## XML and JSON templates

Papercraft XML templates work just like HTML templates:

```ruby
Papercraft.xml { |movies|
  movies.each { |m|
    movie {
      title     m.title
      year      m.year
      director  m.director
    }
  }
}
```

And here's how a JSON template can be generated:

```ruby
Papercraft.json { |movies|
  movies.each { |m|
    item {
      title     m.title
      year      m.year
      director  m.director
    }
  }
}
```

## Extending Papercraft

Since the main goal of Papercraft is to allow developers to produce dynamic
HTML, XML or JSON with the least amount of code, it also includes the
possibility of creating extensions that provide a convenient API for creating
HTML components. This might be particularly useful when using design frameworks
such as Bootstrap or Tailwind, where some components demand quite complex
markup. Here's an example of how a Bootstrap extension might look like:

```ruby
module BootstrapComponents
  ...

  def card(**props)
    div(class: 'card', **props) {
      div(class: 'card-body') {
        emit_yield **props
      }
    }
  end

  def card_title(title)
    h5 title, class: 'card-title'
  end

  ...
end

Papercraft.extension(bootstrap: BootstrapComponents)

my_card = Papercraft.html {
  bootstrap.card(style: 'width: 18rem') {
    bootstrap.card_title 'Card title'
    bootstrap.card_subtitle 'Card subtitle'
    bootstrap.card_text 'Some quick example text.'
    bootstrap.card_link '#', 'Card link'
    bootstrap.card_link '#', 'Another link'
    ...
  }
}
```

## How Papercraft is Used by this website

Papercraft is used by this website, which is, just so you know, not a static
website. While the source layout of this website largely resembles a
[Jamstack](https://jamstack.org/) website, it is rendered dynamically by
[Impression](https://github.com/digital-fabric/impression), a web framework I'm
currently developing for my own use, which in turn relies heavily on Papercraft
for dealing with layouts.

So let's explore how this website is constructed. The file for the present
article is just a markdown file with some YAML front matter
([permalink](https://github.com/ciconia/noteflakes.com/blob/main/sites/noteflakes.com/articles/2021-12-15-extralite.md)):

```md
---
title: Papercraft - Composable Templating for Ruby
layout: article
---

Papercraft is a new Ruby gem I've been working on, that provides a new way to
render HTML, XML and JSON using plain Ruby. Here's what it looks like:

...
```

Here's the layout used for rendering articles
([permalink](https://github.com/ciconia/noteflakes.com/blob/main/sites/noteflakes.com/_layouts/article.rb)):

```ruby
default = import './default'

export_default default.apply { |title:, date:, **props|
  article {
    h1 title
    h3 date.strftime('%d·%m·%Y'), class: 'date'
    emit_yield
  }
}
```

The `article` layout above imports the default layout (using
[Modulation](https://github.com/digital-fabric/modulation)), and uses `#apply`
to create a derivative layout that adds an article element and expects a nested
block to be injected into it.

And here is the default layout ([permalink](https://github.com/ciconia/noteflakes.com/blob/main/sites/noteflakes.com/_layouts/default.rb)):

```ruby
require 'papercraft'

export_default Papercraft.html { |**props|
  html5 {
    head {
      title(props[:title] ? "Noteflakes - #{props[:title]}" : "Noteflakes")
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      style 'body { display: none }' # prevent FUOC
      link rel: 'icon', type: 'image/png', href: '/assets/nf-icon-black.png'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
      link rel: 'alternate', type: 'application/rss+xml', href: '/feeds/rss'
    }
    body {
      header {
        h1 {
          a(href: '/') {
            img src: '/assets/nf-icon-black.png'
            span 'noteflakes'
          } 
        }
        ul {
          li 'by Sharon Rosner', class: 'byline'
          li { a 'archive', href: '/archive' }
          li { a 'about', href: '/about' }
          li { a 'RSS feed', href: '/feeds/rss' }
          li { a 'code', href: 'https://github.com/ciconia', target: '_blank' }
        }
      }
      emit_yield **props
      footer {
        hr
        p {
          span 'Copyright © 2021 Sharon Rosner. This site runs on '
          a 'Impression', href: 'https://github.com/digital-fabric/impression'
          span ' and '
          a 'Tipi', href: 'https://github.com/digital-fabric/tipi'
          span '.'
        }
      }
    }
  }
}
```

Finally, Impression takes the layout referenced in the article's front matter,
and renders it by passing a block that renders the markdown:

```ruby
def render_markdown_file(req, path_info)
  layout = get_layout(path_info[:layout])

  html = layout.render(request: req, resource: self, **path_info) {
    emit path_info[:html_content]
  }
  req.respond(html, 'Content-Type' => layout.mime_type)
end
```

Other templates on this website produce RSS and a [JSON
feed](https://www.jsonfeed.org/). Here's the RSS template
([permalink](https://github.com/ciconia/noteflakes.com/blob/main/sites/noteflakes.com/feeds/rss.rb)):

```ruby
require 'papercraft'

export_default Papercraft.xml(mime_type: 'text/xml; charset=utf-8') { |resource:, **props|
  rss(version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom') {
    channel {
      title 'Noteflakes'
      link 'https://noteflakes.com/'
      description 'A website by Sharon Rosner'
      language 'en-us'
      pubDate Time.now.httpdate
      emit '<atom:link href="https://noteflakes.com/feeds/rss" rel="self" type="application/rss+xml" />'
      
      article_entries = resource.page_list('/articles').reverse

      article_entries.each { |e|
        item {
          title e[:title]
          link "https://noteflakes.com#{e[:url]}"
          guid "https://noteflakes.com#{e[:url]}"
          pubDate e[:date].to_time.httpdate
          description e[:html_content]
        }  
      }
    }
  }
}
```

## A note on Papercraft's design

You will have noticed that Papercraft's DSL looks quite terse, and that is
because all of its API consists basically of unqualified method calls that look
like `html { body { h1 'foo' } }`. This might look confusing to the young Ruby
padawan, as they might ask "where do all these calls go, and how are they
intercepted?"

The answer is that all template procs are evaulated in the context of a
Papercraft
[renderer](https://github.com/digital-fabric/papercraft/blob/master/lib/papercraft/renderer.rb)
instance, which intercepts all calls and turns them into chunks of HTML/XML that
are added to an internal buffer (the [JSON
renderer](https://github.com/digital-fabric/papercraft/blob/master/lib/papercraft/json.rb)
works in a slightly different manner).

On one hand, this allows us to write templates with a minimum of boilerplate,
and have templates that look very clean. On the other hand, it does prevents us
notably from using instance variables, e.g. `@foo` in our templates, and doesn't
let us use any methods in the scope of the receiver where we create our
template. For example, the following code will fail to produce the desired
result:

```ruby
class Foo
  def to_html
    Papercraft.html { h1 bar }
  end

  def bar
    'bar'
  end
end

Foo.new.to_html #=> not what you might expect...
```

So, when writing Papercraft templates we need to follow a few rules:

- Any variables or data referenced inside a template must be provided to the
  template as an explicit argument.
- Any method calls that are not expected to emit HTML should be qualified, i.e.
  the receiver should be referenced explicitly, e.g.: `receiver.foo`.
- No instance variables (or class variables, for that matter) should be used in
  Papercraft templates.

## Conclusion

Papercraft is a new Ruby gem that lets you dynamically generate HTML, XML and
JSON documents using plain Ruby. Papercraft templates use explicit parameter
passing in order to "bind" template variables, and use application and
composition to combine templates in a variety of ways. This website is the first
to use Papercraft "in production", and I hope other people will find it useful.

To learn more about Papercraft, checkout the [API
documentation](https://www.rubydoc.info/gems/papercraft). Contributions in the
form of issues or pull requests will be gladly accepted on the [Papercraft
repository](https://github.com/digital-fabric/papercraft).