---
title: "Steadfast Update I - The Baseline"
description: "I'm a big believer in what Rich Hickey calls Hammock-driven development, a bit of tongue-in-cheek term for solving problems by spending a lot of time thinking about them. Rich talks about the importance of taking the time to think a problem through, instead of rushing to the computer to type out code, and he's right to note that a lot of the big problems with software are problems of misconception, which is really about thinking."
layout: article
---

I'm a big believer in what Rich Hickey calls [Hammock-driven
development](https://www.youtube.com/watch?v=f84n5oFoZBc), a bit of
tongue-in-cheek term for solving problems by spending a lot of time *thinking*
about them. Rich talks about the importance of taking the time to think a
problem through, instead of rushing to the computer to type out code, and he's
right to note that a lot of the big problems with software are problems of
misconception, which is really about thinking.

In my work and in my life I have seen time and again how a lack of thinking
things through before acting can lead to bad results. The Hebrew saying "סוֹף
מַעֲשֶׂה בְּמַחֲשָׁבָה תְּחִלָּה", meaning "the end of a deed is in its initial thought", is
exactly about this - on a philosophical, spiritual, ethical and even a political
level. A wise man would contemplate a plan of action for solving a problem all
the way to its conclusion in his mind, exploring it in all its details, weighing
all consequences and alternatives, before acting on it. Just like a chess player
being able to think through his game dozens of moves in advance. Indeed, imagine
how much better it would be for humanity if our dear leaders had the capacity to
think things through before they act! 😜

Now, it should be noted that I don't spend much time laying in hammocks (we do
have one in our garden, but now in the winter it's not very useful.) But I do
like spending time thinking about code, rather than writing code. I can do this
while doing the dishes, or having a walk, or driving, or listening to music.
Sometimes I just sleep on it, and let my brain process ideas in a background
task. Sometimes I'll write my thoughts in a notebook, which is also a very
helpful process. I'm quite sure most of my working time is spent thinking things
through, and the coding part is in many ways just the artefact of all the
thinking that I did.

This also relates to my latest open-source project,
[Steadfast](https://github.com/digital-fabric/steadfast). This project has been
on my mind for a very long time, and what really helped me push this project
forward was exactly that - spending a lot of a time not only thinking, but also
[sketching my ideas](https://github.com/digital-fabric/sirop) and trying them
out. This helped me identify what problems need to be solved, how the
implementation might work, what the API might look like, and where the limits
are.

## Laying the Baseline

In the last week I was busy laying the foundations for the project. I started
with implementing the functionality of converting a given Prism AST into source
code. This is work that I've [already
done](https://github.com/digital-fabric/sirop) when I wrote the
[Papercraft](https://github.com/digital-fabric/papercraft) compiler, but I
wanted to improve on it in order to prepare for what's going to follow.

Currently there's no way in Ruby to pass an AST to `eval` - indeed that would be
great, but having spent some time reading through the Prism source code, and
also the Ruby runtime source code (more specifically the implementation of
`eval`), it became clear to me that trying to implement such functionality would
not be a trivial undertaking. This mainly has to do with the fact that (as far
as I understand) the Ruby-level Prism AST nodes are in fact reified from the
underlying `pm_node` C structs, but are not backed by them. So if we wanted to
be able to `eval` a given AST , we'd need to be able to convert those Ruby AST
nodes back to `pm_node` structs at the C-level, and then somehow feed that into
the `eval` implementation in order for it to convert the AST into Ruby VM
bytecode.

Being able to do `eval(ast)` would be awesome indeed, and maybe some day the
Ruby runtime may acquire this capability. But for the time being we need to be
able to convert a given AST into source code, which we may then feed to `eval`.
This has the further implication that if we generate code based on a synthetic
AST, for example an AST composed of nodes that were parsed from different
locations in different source files, when an exception is raised we might get
backtraces that are completely nonsensical!

It is with that in mind that I also did some work on being able to track the
original source location of each little piece of the generated source code. This
is complicated by the fact that while each Prism node contains location
information that says where in the source file it resides (the starting and
ending lines and columns,) currently there's no filename information for Ruby
AST nodes. So one thing I did was to add that information to the `Prism::Source`
class, an instance of which is referenced by each AST node, and then use that
information to be able to map each line in the generated source code back to its
original source locations.

Steadfast currently provides the following tools:

- `Steadfast.to_ast(obj)` - this is the tool that converts a given proc or a
  method to its AST. This tool uses the new AST APIs in Ruby 4.1, namely
  `Proc#syntax_tree` and `Method#syntax_tree`, and additionally sets a
  `__filename__` attribute for the underlying `Prism::Source` instance
  referenced by the AST nodes, as described above.

  One of the things I'm still contemplating is providing an alternative for
  using `#syntax_tree` that will make it possible to use Steadfast with older
  versions of Ruby, or if we don't want to enable `RubyVM.keep_script_lines` (more
  info
  [here](https://docs.ruby-lang.org/en/master/RubyVM.html#method-c-keep_script_lines-3D)),
  for reasons of memory usage, for example. The code for that is already there
  in `steadfast.rb` (copied over from Sirop) but currently not hooked up.

- `Steadfast.to_source(obj)` - this tool generates the source code for the given
  proc, method or AST. The generated code is __not__ nicely formatted. There's
  no indentation, and the line breaks may look arbitrary, but this has no
  importance. The [code generation
  algorithm](https://github.com/digital-fabric/steadfast/blob/main/lib/steadfast/sourcifier.rb)
  is rather designed for correctness, ease of testing, and ease of being able to
  correctly translate exception backtraces for composed ASTs (i.e. ASTs
  containing nodes coming from different source locations.) There is a whole
  suite of tests to ensure that the "sourcifier" is able to handle all kinds of
  Ruby syntax - most of the fixtures were adapted from those used for testing
  Prism.

- `Steadfast.translate_backtrace(bt)` - translates the given exception backtrace
  for generated code, such that each backtrace entry will point to the correct
  source location, as discussed above.

## The Steadfast API

When I develop a new gem, I usually start from designing the API, trying to
figure out how the gem would be used by developers. In the case of Steadfast,
I've chosen to provide a single module called `Steadfast`, which provides a
relatively small set of module methods. Otherwise I'm currently not planning to
implement any additional classes or sub modules, at least not ones that are
exposed to the "users" of the gem.

In addition to the above methods that are already implemented, here's the rest
of the API I'm currently planning to implement:

- `Steadfast.mutate(ast, **)` / `Steadfast.mutate(ast) { }` - mutates the given
  AST by either providing replacements for specific nodes (the first form), or
  providing a block that's invoked for each node in the AST, and which may
  return a replacement node. For example, the following (silly example) replaces
  all literal integer values of 42 with 43:

  ```ruby
  mutated_ast = Steadfast.mutate(ast) { |n|
    (n in Prism::IntegerNode(value: 42)) ? Steadfast.quote { 43 } : n
  }
  ```

  Since ASTs are basically immutable, if any replacement was returned by the
  block for a node somewhere in the AST, this method will return a copy of the
  given AST with the necessary changes.

- `Steadfast.walk(ast) { }` - a utility for traversing an AST, invoking the
  block for each node in the AST, a somewhat more convenient way of traversing
  the AST than the APIs currently provided by Prism.

- `Steadfast.find(ast) { }` - a utility that returns the first node for which
  the block returns true. For example, the following returns the first call to
  `#foo`:

  ```ruby
  Steadfast.find(ast) { it in Prism::CallNode(receiver: nil, name: :foo) }
  ```

- `Steadfast.find_all(ast) { }` - similar to `Steadfast.find`, but returns an
  array containing all nodes for which the block returns true.

- `Steadfast.quote { }` - The main feature of Steadfast - this is the tool that
  will allow parametric code generation. This method returns an AST for the
  given block, and expands any `#unquote` and nested `#quote` method calls
  inside the block. I've already written about the possible uses of this tool,
  so I'll not repeat it here, but look below for a cool example of what this
  tool makes possible. This tool will also be accompanied by a whole set of
  special methods for programmtically synthesizing all the different parts of
  the Ruby syntax.

- `Steadfast.eval_ast(ast, receiver, binding, **)` - a utility for `eval`ing the
  given AST with the given receiver and binding. This is also a convenience
  method. It would also provide the capability to wrap the code for a proc or
  method in a `rescue` block that automatically translates the backtrace entries
  for raised exceptions.

I might also implement additional methods for doing handy stuff such as inlining
method calls, rewriting variable names, etc. Also, while this design seems to
answer the requirements of the problem space, as the project progresses I might
choose to evolve the API in order to respond to stuff like concurrency concerns,
namely thread-safety and compatibility with ractors.

Notice that while I'm currently focusing on lower-level tools for working with
ASTs, as those tools become available, some higher-level abstractions may start
to reveal themselves. But let's look at an example of how those lower-level
tools might be used.

## Tail Call Optimization with Steadfast

Here's a use case for Steadfast that occurred to me a few days ago: [tail call
optimization](https://en.wikipedia.org/wiki/Tail_call). Ruby does have the
capacity to do tail call optimization at the VM bytecode level, but this feature
is disabled by default. You need to do the following:

```ruby
RubyVM::InstructionSequence.compile_option = { tailcall_optimization: true }
```

... before `require`ing the code to be optimized, but this seems to be quite a
niche feature of Ruby. With Steadfast however, one might do tail call
optimization simply by manipulating the AST of a given method. Consider the
following recursive implementation of factorial:

```ruby
def fact(n, acc = 1)
  return acc if n <= 1

  fact(n - 1, n * acc) # <- tail call
end
```

Without tail call optimization, calling this method with a large enough `n` (>
10061 on my machine with Ruby 4.0.9) will lead to a `SystemStackError` being
raised, and also there's a performance cost, because of the overhead of method
invocation, hence the use case for tail call optimization, which converts the
method into something like the following:

```ruby
def fact(n, acc = 1)
  loop do
    return acc if n <= 1

    n, acc = [n - 1, n * acc]
  end
end
```

The transformation we do here is to take the body of the recursive method, put
it in a loop, and replace the tail call with a local variable assignment that
updates the method parameters. Here's how this might be done With Steadfast:

```ruby
# @param meth [Method]
def optimize_tail_call(meth)
  ast = Steadfast.to_ast(meth)
  params = ast.parameters
  *body, tail = ast.body.body
  raise "Not a tail call method!" if !(tail in Prism::CallNode(name: meth.name))
  
  ast2 = Steadfast.mutate(ast, ast.body => Steadfast.quote {
    loop {
      unquote(body)
      unquote {
        left = [*params.requireds.map(&:name), *params.optionals.map(&:name)]
        right = tail.arguments.arguments
        quote { __.assign(unquote(left), unquote(right)) }
      }
    }
  })
  Steadfast.eval_ast(ast2, meth.receiver)
end
```

Let's go through this code: we start by retrieving the AST for the given method,
extracting the parameters node, the body excluding the tail, and the tail (the
last statement in the method body) from the AST. Notice how we use the splat
operator to get all statements in the `body` except the last one, which is
assigned to `tail`. We make sure the tail is indeed a *tail call*, i.e.
recursive, and we then create a new AST by mutating the method definition,
replacing the method body with a `loop {}`. We inject the original body
(excluding the tail) into the loop followed by a local variable assignment that
assigns the tail call arguments to the method parameters.

Noteice how the `unquote` calls inside of `quote` are actually executed at
"compile time", i.e. when building the AST. The return value of `unquote` is an
AST node that is injected into the quoted code. The quote/unquote tools work a
bit like interpolated strings - the code is in quotes, and unquote is like the
interpolation operator, which lets you escape out of the quotes in order to make
some computation that will be injected into the quoted code.

Also notice the `__.assign` call, which allows us to synthesize a local variable
assignment with arbitrary left and right sides. This is one of the additional
tools I intend to include in Steadfast, which will allow synthesizing any kind
of AST node. The syntax for these tools is something I'm still working on, so in
the end they might look different.

## What's Next for Steadfast

Now that the baseline capability of generating source code from an arbitrary AST
works, I can turn my attention to the next stage of the project, which will
concentrate on building a robust AST mutation tool. A prototype of
`Steadfast.mutate` already exists in the [testing
code](https://github.com/digital-fabric/steadfast/blob/main/test/test_sourcifier.rb)
(I use it to build inlined ASTs for testing the source mapping functionality).
In addition, I might also work on the `walk`, `find` and `find_all` utilities,
which may also help with testing.

As I wrote above, I spend much of my time thinking about problems rather than
coding. As I continue thinking about Steadfast, I discover new use cases, and
new ways in which we may do code generation. There might be a whole new layer of
higher-level tools waiting to be discovered, based on the basic Steadfast tools
I discussed above, that will allow us to solve problems such as decoding and
encoding HTML, XML, JSON, Protobufs, SQL, and other protocols and formats. Maybe
there's a whole new set of techniques to be discovered for analyzing and
manipulating Ruby source code, in the vein of tools such as Rubocop etc.

How far can we take metaprogramming in Ruby using Steadfast? This is what I
intend to find out in the coming few months.
