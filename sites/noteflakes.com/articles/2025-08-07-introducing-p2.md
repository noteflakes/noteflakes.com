---
title: Introducing P2
layout: article
---

I've just released [P2](https://github.com/digital-fabric/p2), a new HTML
templating engine for Ruby. P2 builds on the work I did in
[Papercraft](/articles/2022-02-04-papercraft), but takes things quite a bit
farther: templates are expressed as plain procs and are automatically compiled
in order to make it fast. How fast?

Here are the results of benchmarking Papercraft against ERB:

```bash
sharon@nf1:~/repo/papercraft$ ruby --yjit examples/perf.rb 
Warming up --------------------------------------
          papercraft    10.187k i/100ms
                 erb    14.435k i/100ms
Calculating -------------------------------------
          papercraft    106.983k (± 4.2%) i/s -    539.911k in   5.057203s
                 erb    155.081k (± 2.4%) i/s -    779.490k in   5.029535s

Comparison:
                 erb:   155080.9 i/s
          papercraft:   106983.3 i/s - 1.45x  slower
```

And here are the results of benchmarking P2 against ERB, with the same template:

```bash
sharon@nf1:~/repo/p2$ ruby --yjit examples/perf.rb 
Warming up --------------------------------------
                  p2    27.859k i/100ms
                 erb    14.935k i/100ms
Calculating -------------------------------------
                  p2    309.524k (± 3.4%) i/s -      1.560M in   5.047232s
                 erb    154.619k (± 2.5%) i/s -    776.620k in   5.026242s

Comparison:
                  p2:   309523.6 i/s
                 erb:   154619.0 i/s - 2.00x  slower
```

So, while Papercraft was about 30% slower than ERB, P2 is about twice as fast!
How does it do that?

## Writing HTML with a Ruby DSL

Of course, Papercraft and P2 are not the only Ruby gems that allow expressing
HTML using plain Ruby. Here's a simple example of a template that will work in
both Papercraft and P2:

```ruby
template = ->(title) {
  div {
    h1 title
  }
}

template.render('Hello') #=> "<div><h1>Hello</h1></div>"
```

This approach to writing HTML templates is very appealing (to me at least). I
find that it is easy to write, easy to read, and also very easy to embed dynamic
values in the produced HTML. But, this approach does have a cost: all those
curly brackets - they denote blocks, and calling methods with blocks is kind of
slow.

It's not like ERB is super fast, but ERB templates are normally compiled to code
that just stuffs strings and interpolated values into a buffer. Surely we can do
the same with the above template. An ideal compiled version of the above
template would look like the following:

```ruby
buffer << "<div><h1>#{CGI.escape_html(title)}</h1></div>"
```

... which looks so deceptively simple. But how can we transform the original
template, with all its curly brackets, into the single line of code above?

## Parsing Ruby Code with Prism

We first need to parse our template code, so we'll be able to transform it. We
do this with [Prism](https://github.com/ruby/prism), Ruby's new parser gem.
Prism takes a piece of source code, and returns an AST (abstract syntax tree)
that we can then manipulate:

```ruby
Prism.parse("-> { h1 'Hello, world!' }").value
#=> @ ProgramNode ... (a whole page's worth of AST nodes)
```

However, some stuff is still missing:

- We want to be able to compile Procs on the fly. How can we dynamically get the
  source code for each proc we want to compile?
- We also need to be able to convert ASTs back into source code. How do we do
  this?

To answer these two questions I have created another gem which I call
[Sirop](https://github.com/digital-fabric/sirop). Sirop takes a `Proc` or a
`Method` object, finds its source code, and then uses Prism to return its AST:

```ruby
require 'sirop'

template = -> { h1 'Hello, world!' }
Sirop.to_ast(template) #=> @LambdaNode ...
```

Sirop also allows us to get the source of the given template:

```ruby
Sirop.to_source(template) #=> "-> { h1 'Hello, world!' }"
```

One important limitation that Sirop has is that it can only work on Procs (or
methods) defined in a file. In other words, it will not work on procs defined in
an IRB session. The same limitation holds for P2 as well.

Sirop provides a `Sourcifier` class that does the conversion of an AST back into
source code. P2 uses the `Sourcifier` class and overrides its stock behaviour in
order to be able to convert calls such as `h1 'Hello, world!'` into strings that
are emitted into a buffer.

## How P2 Compiles Templates

The template compilation process is done using the following steps:

1. Convert the given template Proc into an AST (using Sirop)
2. [Transform the AST](https://github.com/digital-fabric/p2/blob/00382d1da232264d08127e4fa57fbd5c7e10f61a/lib/p2/compiler.rb#L156C2-L188C1) - replacing each instance of `Prism::CallNode` with a
   [`P2::TagNode`](https://github.com/digital-fabric/p2/blob/00382d1da232264d08127e4fa57fbd5c7e10f61a/lib/p2/compiler.rb#L8C3-L49C6).
3. Convert the transformed AST into source code, converting any `TagNode` into
   the appropriate HTML.

The last step is more involved than the first two, and needs to take into
account buffering (for example, taking multiple tag calls and coalescing them
into a single string that's pushed into the buffer), escaping of HTML content,
and dealing with other features that P2 provides, such as deferred rendering,
template composition etc.

## Dealing with Exception Backtraces

Another consideration to take into account when compiling templates is that any
exception raised while rendering the template will show an incorrect backtrace.
P2 generates a *source map* mapping line numbers in the compiled proc to line
numbers in the original proc source code. This allows us to manipulate the
backtrace for any exception raised while rendering, such that any entry
occurring in the compiled proc will point to the corresponding line in the
original template source code:

```ruby
require 'p2'

template = -> {
  h1 'foo'
  raise 'bar'
}
puts '*' * 40
puts template.compiled_code


template.render #=> throws an exception...
```

And the backtrace will show the line where the exception was raised, except that
the code that actually ran is completely different!
```
test.rb:5:in 'block (2 levels) in <main>': bar (RuntimeError)
	from /home/sharon/.rbenv/versions/3.4.5/lib/ruby/gems/3.4.0/gems/p2-2.0.1/lib/p2/proc_ext.rb:31:in 'Proc#render'
	from test.rb:11:in '<main>'
```

## Some Future Directions

The automatic compilation of Ruby DSLs can bring other benefits beyond just
performance improvements. We can really extend the syntax in order to make it
easier to express HTML. Here are some ideas I am currently exploring for
extending the syntax for expressing HTML tags and attributes:

```ruby
# syntax for specifying id's:
h1[:foo] 'bar' #=> <h1 id="foo">bar</h1>

# syntax for specifying class:
h1.foo 'bar' #=> <h1 class="foo"></h1>

# syntax for specifying arbitrary attributes:
a.href('/about') 'About' #=> <a href="/about">About</a>
```

Another direction I'm exploring is being able to extend the DSL by expressing
extensions as Procs, and having P2 automatically inline them:

```ruby
P2.extend(
  ulist: ->(list) {
    ul {
      list.each {
        li it
      }
    }
  }
)
```

Currently, P2 is perfectly able to emit procs, but the code looks like this:

```ruby
# source
->(items) {
  div { emit ulist(items) }
}

# compiled template
->(__buffer__, items) {
  __buffer__ << "<div>#{P2.render_emit_call(ulist(items))}</div>"
  ...
}
```

With proc inlining, it would look like this:

```ruby
->(__buffer__, items) {
  __buffer__ << "<div><ul>"
  items.each {
    __buffer__ << "<li>#{CGI.escape_html(it.to_s)}</li>"
  }
  __buffer__ << "</ul></div>"
  ...
}
```

That's it for now. If you find P2 useful, please let me know, and feel free to
contribute issues or PR's here: https://github.com/digital-fabric/p2
