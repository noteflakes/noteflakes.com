---
title: "Papercraft 3.0 Released"
layout: article
---

I have just released [Papercraft](https://papercraft.noteflakes.com/) version
3.0. This release includes a new API for rendering templates, improved XML
support and an improved API for the `Papercraft::Template` wrapper class. Below
is a discussion of the changes in this version, as well as what's coming in the
near future.

## A New Rendering API

Papercraft 2.0 was all about embracing lambdas as the basic building block for
HTML templates. Papercraft 2.0 introduced automatic compilation of Papercraft
templates into an optimized form that provides best-in-class performance. The
two most important operations on templates were `#render` and `#apply`:

```ruby
# Papercraft 2.0:
Greet = ->(name) { h1 "Hello, #{name}!" }
Greet.render("world") #=> "<h1>Hello, world!</h1>"

# alternatively
GreetWorld = Greet.apply("world")
GreetWorld.render #=> "<h1>Hello, world!</h1>"
```

While this API is certainly very elegant and convenient, there was legitimate
concern among potential users that Papercraft was in effect extending the core
[`Proc`](https://rubyapi.org/o/proc) class, with generic name methods that are
specific to Papercraft templates, while `Proc`s are in fact used everywhere in a
given Ruby codebase, and not only for templates (everytime you call a method
with a *block*, that block is in fact a `Proc` instance).

So, after giving it some thought I've decided to change the Papercraft API such
that the act of rendering a template or applying arguments to a template will be
done with singelton methods on the `Papercraft` module:

```ruby
# Papercraft 3.0:
Greet = ->(name) { h1 "Hello, #{name}!" }
Papercraft.render(Greet, "world") #=> "<h1>Hello, world!</h1>"

# alternatively
GreetWorld = Papercraft.apply(Greet, "world")
Papercraft.render(GreetWorld) #=> "<h1>Hello, world!</h1>"
```

I think this change is a big step forward for Papercraft. It demarcates an
important distinction between writing templates in the form of lambdas using the
Papercraft DSL, and the actual rendering (or application) of said templates,
which is done at the edges of the program, when those templates are actually
used.

This change further embraces the functional style in Ruby, a style of
programming I've been gravitating towards in the last few years, with an
emphasis on explicitness and conciseness. I like that `Papercraft.render` and
`Papercraft.apply` are simply functions that take templates (and optional
arguments) as input and return a string as output.

## Improved XML Support

While Papercraft 2.0 was concerned exclusively with HTML, I've decided to bring
back support for rendering XML, even if only for the sake of being able to
render RSS feeds. Version 3.0 introduces improved support for rendering XML. You
can now render XML templates by calling `Papercraft.xml`:

```ruby
template = ->(items) {
  articles {
    items.each {
      item it
    }
  }
}
Papercraft.xml(template, ['foo', 'bar'])
```

Papercraft 3.0 also adds support for rendering self-closing XML tags, for
elements with no inner text or child nodes:

```ruby
Papercraft.xml { item(ref: "foo") }
#=> "<item ref=\"foo\"/>"
```

## A Streamlined Papercraft::Template Class

A few months ago, Papercraft version 2.4 introduced a wrapper class for
templates called `Papercraft::Template`. The use case for this class was to be
able to distinguish between template `Proc`s and non-template `Proc`s. With the
new rendering API introduced in version 3.0, the `Papercraft::Template` class
has also undergone some changes, with its interface streamlined and simplified:

```ruby
Greet = Papercraft::Template.new { |name| h1 "Hello, #{name}!" }
Greet.render("world")
#=> "<h1>Hello, world!</h1>"
```

You can also use this class to render XML templates, by passing `mode: :xml` to
`Template.new`:

```ruby
Papercraft::Template.new(mode: :xml) { ... }
```

People that are have been using Papercraft since before version 2.0 API may
prefer to use the `Papercraft::Template` class, which is in many ways similar to 
the original Papercraft API.

## Coming Soon: Support for Inlining

When rendering complex HTML, and as your application grows, there's a natural
tendency to prefer to put separate parts of the markup in separate templates,
which are then composed together. Papercraft makes this very easy to do, whether
in the form of layouts, derived layouts, components or partials. But while the
quality of your code is improved, this may come at a significant cost to
rendering performance.

This problem is not unique to Papercraft. Any templating solution, be it
[ERB](https://github.com/ruby/erb) or [Phlex](https://www.phlex.fun/) is going
to suffer from the same problem. ERB is especially
[susceptible](https://github.com/rails/rails/issues/41452) to this.

One of the ideas I've been exploring since the release of automatic template
compilation in Papercraft 2.0, was automatic inlining of sub-templates. Consider
the following example:

```ruby
Card = ->(title:, text:) {
  card {
    h1 title
    p text
  }
}
Deck = ->(items) {
  deck {
    items.each {
      Card(**item)
    }
  }
}
```

Currently, Papercraft will optimize `Card` and `Deck` separately, and the
compiled `Deck` template while call the compiled `Card` template for each item:

```ruby
# compiled code (edited for legibility)
->(__buffer__, items) {
  __buffer__.<<("<deck>")
  items.each {
    Card.__papercraft_compiled_proc.(__buffer__, **item)
  }
  __buffer__.<<("</deck>")
  __buffer__
}
```

If Papercraft were capable of inlining sub-templates, the compiled `Deck`
template would have looked something like the following:

```ruby
->(__buffer__, items) {
  __buffer__.<<("<deck>")
  items.each {
    __buffer__.<<("<card><h1>")
      .<<(ERB::Escape.html_escape((item[:title])))
      .<<("</h1><p>")
      .<<(ERB::Escape.html_escape((item[:text])))
      .<<("</p></card>");
  }
  __buffer__.<<("</deck>")
  __buffer__
}
```

## It's AST's All the Way Down!

I've spent months thinking about this problem and had no clear idea of how this
could be implemented. A quick recap: when Papercraft compiles a template it does
it in three steps: first it loads the source code for the template and parses it
using [Prism](https://github.com/ruby/prism), then the AST is mutated to convert
tag method calls to custom nodes, and finally the mutated AST is converted back
to optimized source code that is eval'd to produce the compiled template proc.

At first I presumed that inlining should be done at the last step, when
converting the mutated AST to source code. But I had no clear idea on how to do
this. Then, yesterday, I was making some notes for a talk I'm preparing about
Papercraft and functional programming in Ruby, and I had a *Eureka* moment when
I realized this could be solved by mutating and combining ASTs!

If we look at each template in terms of an AST, instead of its source code, the
solution becomes clear: whenever we encounter a `CallNode` with the tag `Card`,
we can simply replace this node with the AST of the corresponding template.

There's some work to be done around translating arguments between the original
call and the actual arguments used by the inlined AST, but this is certainly
doable. In addition, this technique can be applied not only to rendering
components, but also to the composition of layouts using `render_yield`, or any
usage of `Papercraft.apply`.

I'm really excited to be implementing this feature, and making Papercraft the
best *and fastest* HTML templating engine for Ruby. In the meanwhile, feel free
to explore [Papercraft](https://papercraft.noteflakes.com/) and start using it
in your app.