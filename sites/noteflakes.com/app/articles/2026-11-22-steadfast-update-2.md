---
title: "Steadfast Update II - Rewriting ASTs"
description: "In the last Steadfast update I discussed the foundations of the project, its general API design, and my work on implementing the basic capacity of turning ASTs back to source code. In this update I'm discussing a new tool for rewriting Ruby ASTs."
layout: article
---

> Steadfast is a new Ruby project that aims to provide a new way to dynamically
  generate Ruby code at runtime by synthesizing and manipulating ASTs, as an
  alternative to the common technique of calling `eval` with a dynamically generated string containing Ruby source code.

In the [last Steadfast update](/articles/2026-11-13-steadfast-update-1) I
discussed the foundations of the project, its general API design, and my work on
implementing the basic capacity of turning ASTs back to source code (using
`Steadfast.to_source`), as well as providing some facilities for translating
backtrace locations for code derived from AST that were composed of pieces of
code from different locations.

Over the last few days, I've concentrated on implementing the ability to
transform an existing AST by replacing specific nodes therein. Previously, I
called this "mutating" an AST, but actually I realized this term might be
confusing, since Prism ASTs are inherently *immutable*, that is, they cannot be
modified. Instead, you need to create a copy of an AST node with the requisite
changes, so using the verb "mutate" is in fact incorrect. So henceforth I'll use
the term "rewrite" instead, which seems more fitting, since we're basically
taking existing code and *rewriting* it.

So, if Prism nodes are immutable, how can we rewrite them? Basically, Prism lets
us create a copy of a given node, with specific attributes assigned new values:

```ruby
node.copy(foo: some_value)
```

Now, there are some interesting nuances to this, because Prism nodes basically
have three different *kinds* of attributes:

- Child nodes - those are references to sub nodes. For example, a `CallNode`,
  representing a method call, will have a `receiver` subnode, that refers to the
  method receiver.
- Plain value attributes - those are attributes that describe metadata
  associated with the node. For example, a `CallNode` will have a `name`
  attribute, whose value is a symbol, representing the name of the method to
  call.
- Location attributes - those are references to `Prism::Location` instances that
  reference specific pieces of the source code syntax. For example, a `CallNode`
  will have a `call_operator_loc` attribute that references the `.` character
  for method calls with receivers. It will also reference the respective
  locations of the open and close parens, if the method call uses them.

That last group of node attributes, locations, is actually what Steadfast uses
in order to convert a given AST back to a string containing Ruby code. So, if we
want to rewrite a given node, we can't just create a copy of it with its plain
value attributes changed. For example, if we have a method call `foo`, which we
want to change to `bar`, we can't just rewrite the corresponding `CallNode` with
a modified `name` attribute, because the location attribute for this (called
`message_loc`) will still point to the original source code containing the
string `foo`. We actually need to replace the `CallNode` with a *another*
`CallNode` that actually represents a call to `bar`.

That means that we need to be able to synthesize that node. Here's how this
might be done:

```ruby
def make_call_node(name)
  l = eval("-> { #{name} }")
  # Extract the first statement in the lambda body
  Steadfast.to_ast(l).body.body[0]
end
```

We can then proceed to replace the call_node

```ruby
# the original code:
l = -> { foo }

l_ast = Steadfast.to_ast(l)
body_node = l_ast.body

rewritten_body_node = body_node.copy(body: [make_call_node(:bar)])
rewritten_ast = l_ast.copy(body: rewritten_body_node)

rewritten_lambda = eval(Steadfast.to_source(rewritten_ast))
```

In the above example, we acquire the lambda AST, then we get its body, create a
copy of it containing the synthesized call to bar, and create a copy of the
original AST, with the rewritten body.

As you can see, this is not very convenient. We need to reach into the AST to
extract the body of the lambda, which is a `StatementsNode`, and we then need to
inject the replacement method call into it. Once the body is rewritten, we need
to create a copy of the lambda node itself, so it will point to the new body.

In the above example, we just needed to touch the body node, which is a subnode
of the lambda root node, but in other cases we might need to drill down and make
changes to some subnodes that are nested a lot deeper in the AST, which means
that for any node that was replaced, we also need to replace *all* its parent
nodes.

So this is what I set out to solve with `Steadfast.rewrite`. The implementation
is quite simple: for any modification (rewrite) of a subnode, we automatically
create modified copies of all its parent right up to the root. That's why
`Steadfast.rewrite` trakes an AST as its first argument, and returns a rewritten
AST as its return value.

To show how `Steadfast.rewrite` can be used, let's look at two possible
applications of this technique:

## Example 1: Tail Call Optimization

In the previous update, I discussed a possible way to do tail call optimization by rewriting an AST. Take for example a recursive factorial method:

```ruby
def fact(n, acc = 1)
  return acc if n <= 1

  fact(n - 1, n * acc)
end
```

We can do tail call optimization by rewriting it as follows:

```ruby
def fact(n, acc = 1)
  loop do
    return acc if n <= 1

    n, acc = [n - 1, n * acc]
  end
end
```

Basically, we rewrite the method by putting everything in a loop, and replacing
the tail call with a multiple local variable assignment. Here's how we can do it
using `Steadfast.rewrite`:

```ruby
def rewrite_with_tail_call(meth)
  ast = Steadfast.to_ast(meth)
  params = ast.parameters
  *body, tail = ast.body.body

  body2 = make_loop(*body, convert_tail_call(tail, params))
  ast2 = Steadfast.rewrite(ast, ast.body => { body: body2 })
  eval(Steadfast.to_source(ast2))
end
```

The method above extracts the AST for the given method, separates the method
body into a `body` (containing all statements but the tail), and a `tail` which
references the last statement. We then synthesize a loop node containing the
`body` and the converted `tail`, and call `Steadfast.rewrite` to replace the
original body with the loop. Finally, we call `eval` with the rewritten source
code, which effectively redefines the method. Here's how we make the loop node:

```ruby
def make_loop(*statements)
  l = eval("-> { loop do; 1; end }")
  loop_node = Steadfast.to_ast(l).body.body[0]
  loop_block_body = loop_node.block.body
  Steadfast.rewrite(loop_node, loop_block_body => { body: statements })
end
```

We synthesize a call to loop, and then use `Steadfast.rewrite` to inject the
given list of statements into its body. To convert the tail call, we use a
similar technique:

```ruby
def convert_tail_call(tail, params)
  make_multi_write_node(
    [*params.requireds.map(&:name), *params.optionals.map(&:name)],
    tail.arguments.arguments
  )
end

def make_multi_write_node(names, values)
  l = eval("-> { #{names.join(', ')} = [nil] }")
  multi_write_node = Steadfast.to_ast(l).body.body[0]
  Steadfast.rewrite(multi_write_node, multi_write_node.value => { elements: values })
end
```

We synthesize a multi-write node (representing assignment to multiple local
variables) with the given variable names, and we use `Steadfast.rewrite` to
inject the tail call arguments into the assignment as an array.

## Example 2: Pipe Operator Implementation

A nifty feature of Elixir is the ability to use a pipe operator (`|>`) for
putting data through a series of transformations. This does not really exist in
Ruby, though you can use the somewhat unwieldy syntax `.then { ... }`. While
method chaining is quite useful for many kinds of computations, sometimes you
wish you had something like a pipe operator in Ruby, the idea being that at each
step of the pipe, we inject the last return value as the first argument to the
next method call. What if we could do something like the following:

```ruby
pipe { 1 >> add(2) >> mul(3) >> pow(4) }
```

Since in Ruby, binary operators are implemented as method calls, but with a
special syntax, the following is synonymous with the above:

```ruby
pipe { 1.>>(add(2)).>>(mul(3)).>>(pow(4)) }
```

Interestingly, the AST representation of the code will have the call to `pow` at
the top of the AST (that is, on the outside), with the preceding calls being
expressed as the *receiver* of that method call, something like the following:

```ruby
>>(
  receiver: >>(
    receiver: >>(
      receiver: 1,
      arguments: [add(2)]
    ),
    arguments: [mul(3)]
  ),
  arguments: [pow(4)]
)
```

But this code is just an intent, it won't acutally work since any of those calls
to `add`, `mul` and `pow` needs to provide two arguments. We need to be able to
transform this syntax into a sequence of method calls where the result of each
method call is injected as an argument into the next one.

The rewrite operation we need to do is to flip the receiver and the argument for
each call to `>>`, such that the argument becomes the method call, and the
receiver is injected as an additional first argument into that method call, in
order to achieve the following:

```ruby
-> { pow(mul(add(4, 3), 6), 2) }
```

Here again, we can use `Steadfast.rewrite` to do just that:

```ruby
l = -> { 1 >> add(2) >> mul(3) >> pow(4) }
l_ast = Steadfast.to_ast(l)
p_ast = Steadfast.rewrite(l_ast) { |n, &r|
  next n if !(n in Ruby::Prism::CallNode(name: :>>))

  call_node = n.arguments.arguments[0]
  next n if !n in Ruby::Prism::CallNode

  arguments = [Steadfast.rewrite(n.receiver, &r), call_node.arguments]
  Steadfast.rewrite(call_node, call_node.arguments => { arguments: })
}
p = eval(Steadfast.to_source(p_ast))
```

In this example, instead of providing `Steadfast.rewrite` with a list of
specific node replacements, we give it a block that is invoked for each node in
the AST. The block should return either a replacement node, or the original
node, in which case no replacement is made.

In the rewriter block, we filter out anything that is not a call to `>>` (since
in Ruby, binary operators are actually method calls). Notice how we use `next n`
to tell `Steadfast.rewrite` that no replacement is made and that we want to
continue visiting other nodes. We then extract the call_node to the right of the
`>>` operator (its argument), and replace the operator call with this call node,
with its arguments rewritten so as to inject the value to the left of the
operator into the call.

Notice how we recursively call `Steadfast.rewrite(n.receiver, &r)`. In order to
make it possible for us to recurse inside the block, `Steadfast.rewrite` yields,
along with the node, a reference to the block itself, which lets us call
`Steadfast.rewrite` recursively with the same block. This technique is
interesting in and of itself, and is quite useful as you can see, since working
with ASTs is inherently recursive.

Pipe operator syntax transformation and tail call optimization are but two
possible applications of AST rewriting, but `Steadfast.rewrite` can also be used
for inlining method calls, and more generally, for such things as wrapping code
in a loop, or in a begin/rescue block, unrolling loops, injecting arguments into
method calls... the possibilities are endless!

In the upcoming stages of this project, I'll use `Steadfast.rewrite` to
implement the code quoting tool (aka quote/unquote), as well as for synthesizing
different kinds of AST nodes.

## The Steadfast.rewrite Implementation

The `Steadfast.rewrite` implementation is surprisigingly succint, about 35LOC.
At the heart of it is the following method that visits each node in the AST:

```ruby
def visit(node)
  node2 = @rewrite_block.(node, &@rewrite_block)
  return node2 if node2 != node

  changes = {}
  node.deconstruct_keys(nil).each do |k, v|
    if v.is_a?(Ruby::Prism::Node)
      v2 = visit(v)
      changes[k] = v2 if v2 != v
    elsif v in [Ruby::Prism::Node, *]
      v2 = v.map { visit(it) }
      changes[k] = v2 if v2 != v
    end
  end
  changes.empty? ? node : node.copy(**changes)
end
```

We start the visit by invoking the rewrite block with the given node. If a
replacement node was returned by the block, we return it immediately. Otherwise,
we dive into the node attributes (using `deconstruct_keys`), and visit each
subnode, or array of subnodes. If any replacements were returned for any of the
attributes, we make a copy of the node with the relevant changes. Thus we ensure
that any replacement to a nested node will result in its parent being replaced
as well, all the way up to the root of the AST.

To allow `Steadfast.rewrite` to be called with a hash of replacements instead of a visitor block, we do the following:

```ruby
rewrite_block ||= ->(n) do
  if (v = replacements[n]) && v.is_a?(Hash)
    n.copy(**v)
  else
    replacements.key?(n) ? replacements[n] : n
  end
end
```

And that's basically all there is to it - we have a general purpose tool for
rewriting ASTs!

## What's Next for Steadfast

My plan for this coming week is to spend some time on creating tools for
synthesizing different kinds of nodes more easily. We've seen some examples of
this in the discussion above, for example:

```ruby
def make_call_node(name)
  l = eval("-> { #{name} }")
  Steadfast.to_ast(l).body.body[0]
end
```

I already have some ideas about how this could be improved and generalized, and
I also want to design an API that will be convenient to use, even for people who
are less familiar with ASTs.

In addition, some more work should be done on being able to maintain correct
backtraces for exceptions raised in code based on synthetic ASTs. This is
definitely something on which I'm going to spend more time, and more tests.
