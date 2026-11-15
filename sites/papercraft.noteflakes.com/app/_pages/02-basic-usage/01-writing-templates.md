---
title: Writing Templates
---

Papercraft templates are expressed as Ruby lambdas. Ruby lambdas are simply
anonymous functions, and use the following syntax:

```ruby
->(...) { ... }
```

A lambda is defined by using the arrow operator `->` followed by optional
arguments, and finally a body inside curly brackets `{ }`.

## Template Arguments

A lambda can take 0 or more arguments. You can define lambda arguments just like
you would in a Ruby method:

```ruby
# no arguments:
-> { }

# positional arguments:
->(foo, bar) { }

# keyword arguments:
->(foo:, bar:) { }

# mix of positional and keyword arguments:
->(foo, bar, baz:) { }

# default values
->(foo, bar = 1, baz: 2) { }

# rest arguments
->(foo, bar, *rest) { }

# explicit block argument:
->(foo, &block) { }
```

## The Template Body

The template body is simply a sequence of Ruby statements. HTML tags are emitted
by making receiver-less method calls:

```ruby
-> {
  h1 "Title"
  h2 "Sub-title"
  p "Some text"
}
```

You can express any kind of logic or loops inside your templates, right along
your HTML tags:

```ruby
->(items) {
  h1 "Title"
  if items
    ul {
      items.each {
        li it.title
      }
    }
  end
}
```

## Template Constants

Since Ruby lambdas are merely expressions, you'd want to assign them to a
constant in order to be able to reference them later:

```ruby
# assign to a constant:
Foo = -> { h1 "Hi" }
```

As you'll see further on, assigning templates to constants allows us to use them
as sub-templates, or components, inside other templates.

## Templates as Pure Functions

While Ruby lambdas can also act as closures (that is, capturing the local
binding along with the local variables and any instance variables,) Papercraft
encourages passing all dynamic data used inside the template as explicit
arguments. So, by convention, you should avoid using any local variables defined
outside the template or any instance variables inside your templates, and
instead define them as arguments:

```ruby
# instead of this:
foo = "foo"
template = -> { h1 foo }
Papercraft.html(template)

# do this:
template = ->(foo) { h1 foo }
Papercraft.html(template, "foo")
```
