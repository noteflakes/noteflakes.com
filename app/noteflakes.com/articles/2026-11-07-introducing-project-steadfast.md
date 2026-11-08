---
title: "Introducing Project Steadfast"
description: "Steadfast is an exploration of how far we can take metaprogramming in Ruby using new tools for manipulating Ruby ASTs"
layout: article
---

Recently I [wrote about an idea](./2026-10-07-unrolled-code) that's been
floating around in my mind for a long time - the ability to do metaprogramming
in Ruby by manipulating Ruby ASTs, similar to the macro capabilities of
languages such as Lisp or Elixir. The use of `eval` (in its different
variations) is a common metaprogramming technique in Ruby that consists of
generating code at runtime from dynamically constructed strings. This is often
done for performance reasons: ERB compiles templates into optimized code by
generating pieces of Ruby source code then putting them together and calling
`eval`; In Rails, the same technique is used for implementing features such as
associations, or scaffolding. With `eval`, we can avoid paying the performance
overhead that's often associated with using DSLs in Ruby.

But using `eval` in a highly-dynamic context may also be error-prone, limited,
and potentially vulnerable to injection attacks. Having to painstakingly
construct strings containing Ruby source code can be an arduous task, especially
if you want to compile a DSL into efficient code, as in the case of ERB, or my
own [Papercraft](https://github.com/digital-fabric/papercraft).

In Papercraft, HTML is generated using a DSL. Here's an example:

```ruby
header {
  p { strong(repo_name) }
  p(repo_description)
  p { code(clone_command) }
}
```

While this kind of code may be used to generate HTML using the [builder
pattern](https://armandfardeau.github.io/design-patterns-in-ruby/builder.html),
which is the traditional way of implementing DSLs in Ruby, it introduces a
significant performance overhead. That is why in Papercraft I chose to implement
a compiler that takes the code above and compiles it into the optimized form:

```ruby
__buffer__
  .<<("<header><p><strong>").<<(ERB::Escape.html_escape((repo_name)))
  .<<("</strong></p><p>").<<(ERB::Escape.html_escape((repo_description)))
  .<<("</p><p><code>").<<(ERB::Escape.html_escape((clone_command)))
  .<<("</code></p></header>")
```

This does solve the performance problem (on par with ERB templates), it
introduces a different problem, that complexity in the Papercraft compiler code
itself. I'm not particularly proud of the [Papercraft compiler
code](https://github.com/digital-fabric/papercraft/blob/master/lib/papercraft/compiler.rb),
which complexity stems from the fact that the kind of optimized code is
generated dnyamically, and has to be put together from many small pieces. That's
why I've long been thinking about how to simplify it.

It eventually occurred to me that a tool for generating code using a
general-purpose macro expansion technique, such as the quote/unquote mechanisms
in languages such as Lisp or Elixir, might be a perfect fit for solving problems
such as this. Such a tool may not only be used for generating new code at
runtime, but can also be used for manipulating and mutating existing code at
runtime.

## A Quote/Unquote Example

As a very simple example of how this technique may be used, let's implement a
general-purpose validator generator. Its job is to generate a validator lambda
that validates a given value against one or more conditions, which we'll do
using the `===` operator (this is the operator used for matching `case` clauses
in Ruby). We can just generate a closure and iterate over the conditions:

```ruby
def create_validator(*conds)
  ->(v) {
    conds.each { raise unless it === v }
    v
  }
end
```

That's pretty nice and simple, but if we wanted to squeeze a bit more
performance out of it we might want to unroll that `conds.each` loop, which we
can do by interpolating a string containing the unrolled code, then pass it to
`eval`:

```ruby
def create_validator(*conds)
  code = <<~RUBY
    ->(v) {
      #{conds.map { "raise unless (#{it.inspect}) === v;" }.join}
    }
  RUBY
  eval(code)
end
```

This is perfectly doable, but notice that we have to nest the embedded code
inside of the string we're building, which is kind of unwieldy. With a
quote/unquote tool, which let's us build Ruby code out of Ruby code, we could do
the following:

```ruby
def create_validator(*conds)
  ast = quote {
    ->(v) {
      unquote conds.map { |c| quote { unquote(c) === v } }
      v
    }
  }
  eval(ast.to_source)
end
```

With `#quote` we're putting code inside quotes (obviously), and with `#unquote`
we're temporarily escaping out of the quotes in order to perform some
computation and inject the result back into the quoted code. In this case, we're
converting each of the conditions into a piece of Ruby AST by calling `quote {
unquote(c) === v }`.

In my article [Unrolled Code](./2026-10-07-unrolled-code), I've explored how
this technique could be applied to many different problems. Which leads us to
project Steadfast.

## Project Steadfast

I'm excited to announce that I've been selected as the recipient of a [Ruby
Association grant](https://www.ruby.or.jp/en/news/20261102) for working on
developing a general-purpose macro tool for Ruby using the quote/unquote
technique, with Matz as my mentor.

The scope of the project includes the development of the quote/unquote tools, as
well as additional tools for generating and manipulating Prism ASTs, converting
ASTs to source code, etc. The project will also explore the use of those tools
in popular gems such as ERB, ActiveRecord, Roda etc. I'd like to see how far I
can take those ideas, how can they be integrated into the Ruby runtime, and what
are the limitations and drawbacks of this technique.

I'll do this work in a new repository that I created called
[Steadfast](https://github.com/digital-fabric/steadfast). If you wish, you can
look at some [sketches I
made](https://github.com/digital-fabric/steadfast/blob/main/grant-2026/sketches.md)
that show possible usages for quote/unquote. Steadfast is a continuation of my
work on [Sirop](https://github.com/digital-fabric/sirop), a tool I built for
converting Prism ASTs to source code, and which is currently used by the
Papercraft compiler.

Steadfast is dedicated to the courageous people of the land who persevere in the
face of unimaginable violence, persecution, callousness and indifference.

<p align="center">
  <img src="/assets/steadfast-logo.png" style="width: 50%">
</p>

Over the next four months, I'll be sharing news of my progress on this project,
which should be completed by late March 2027. I think the new techniques
introduced in this project can lead to a new way of doing metaprogramming in
Ruby. Hopefully, other people will find this work useful and will come up with
new uses for Steadfast.
