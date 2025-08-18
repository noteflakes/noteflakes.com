---
title: "How I Made Ruby Faster than Ruby"
layout: article
---

If you're a Ruby programmer, you most probably will be familiar ERB templates
and the distinctive syntax where you mix normal HTML with snippets of Ruby for
embedding dynamic values in HTML.

I wrote [recently](/articles/2025-08-07-introducing-p2) about
[P2](https://github.com/digital-fabric/p2), a new HTML templating library for
Ruby, where HTML is expressed using plain Ruby. Now this is nothing new or even
unique. There's a lot of other Ruby gems that allow you to do that:
[Phlex](https://www.phlex.fun/), (my own)
[Papercraft](https://github.com/digital-fabric/papercraft) and
[Ruby2html](https://github.com/sebyx07/ruby2html) come to mind.

What is different about P2 is that the template source code is always compiled
into an efficient Ruby code that generates the HTML. In other words, the code
you write inside a P2 template is actually never run, it just serves as a
*description* of what you actually want to do.

While there have been some previous attempts to use this technique for speeding
up template generation, namely Phlex and Papercraft, to the best of my knowledge
P2 is the first Ruby gem that actually employs this technique *exclusively*.

In this post I'll discuss how I took P2's template generation performance from
"OK" to "Great". Along the way I was
[helped](https://github.com/digital-fabric/p2/pull/1) by Jean Boussier, a.k.a.
[byroot](https://github.com/byroot) who not only showed me how far P2 still has
to go in terms of performance, but also gave me some possible directions to
explore.

## How P2 Templates Work

Here's a brief explanation of how P2 compiles template code. In P2, HTML
templates are expressed as Ruby Procs, for example:

```ruby
->(title:) {
  html {
    body {
      h1 title
    }
  }
}.render(title: 'Hello from P2') # "<html><body><h1>Hello from P2</h1></body></html>"
```

Calling the `#render` method will automatically compile and run the generated
code, which will look something like the following:

```ruby
->(__buffer__, title:) {
  __buffer__ << "<html><body><h1>"
  __buffer__ << ERB::Escape.html_escape((title).to_s)
  __buffer__ << "</h1></body></html>"
  __buffer__
}
```

As you can see, while the original source code is made of nested blocks, the
generated code takes an additional `__buffer__` parameter and pushes snippets of
HTML into it. Any dynamic value is pushed separately after being properly
escaped.

Let's quickly go over how this code transformation is achieved. First, P2
locates the source file where the template is defined, and parses the template's
source code (using a little gem I wrote called
[Sirop](https://github.com/digital-fabric/sirop)) into a Prism AST. Here's a
part of the AST for the above example, showing the call to `body` with the
nested `h1` (with non-relevant parts removed):

```
@ CallNode (location: (6,4)-(8,5))
├── receiver: ∅
├── name: :body
├── arguments: ∅
└── block:
    @ BlockNode (location: (6,9)-(8,5))
    ├── locals: []
    ├── parameters: ∅
    └── body:
        @ StatementsNode (location: (7,6)-(7,14))
        └── body: (length: 1)
            └── @ CallNode (location: (7,6)-(7,14))
                ├── receiver: ∅
                ├── name: :h1
                ├── arguments:
                │   @ ArgumentsNode (location: (7,9)-(7,14))
                │   └── arguments: (length: 1)
                │       └── @ LocalVariableReadNode (location: (7,9)-(7,14))
                │           ├── name: :title
                │           └── depth: 2
                └── block: ∅
```

(You can look at the AST for any proc by calling `Sirop.to_ast(my_proc)` or
`my_proc.ast`.)

Now if we look at the above DSL we can see that the calls to `html`, `body` and
`h1` are represented as nodes of type `CallNode`, and those nodes have the
`receiver` set to nil (because there's no receiver), and that the HTML tag name
is stored in `name`. So the first step in transforming the code is to translate
each CallNode into a custom node type that could later be used to generate
snippets of HTML that will be added to the HTML buffer. The translation is
performed by the `TagTranslator` class, which looks for specific patterns and
when a pattern is matched, replaces the given node with a custom node. Let's
look at `TagTranslator#visit_call_node`:

```ruby
class TagTranslator < Prism::MutationCompiler
  ...

  def visit_call_node(node, dont_translate: false)
    return super(node) if dont_translate

    match_builtin(node) ||
    match_extension(node) ||
    match_const_tag(node) ||
    match_block_call(node) ||
    match_tag(node) ||
    super(node)
  end

  ...
end
```

A `Prism::MutationCompiler` is a class that returns a modified AST based on the
return value of each `#visit_xxx` method. So `#visit_call_node`, as its name
suggests, visits nodes of type `CallNode` and the return value is used for
mutating the AST. If we look at the `#match_tag` method, we'll see how the call
node is transformed:

```ruby
def match_tag(node)
  return if node.receiver

  TagNode.new(node, self)
end
```

So what happens is that for normal HTML tags, the `#match_tag` method will
return a custom `TagNode`. Once the entire AST is traversed, we we'll have a
mutated AST where all relevant calls have been translated into instances of
`TagNode` (there are other custom node classes that correspond to other parts of
the P2 DSL).

The next step is to transform the mutated AST back to source. The heavy lifting
is done by the Sirop gem, with the `Sourcifier` class, which allows us to
transform a given AST to Ruby source code. But the Sirop sourcifier doesn't know
anything about those custom P2 node types, such as `TagNode`, so we need to help
it a bit. We do this by subclassing it, and adding some code for dealing with
all those custom nodes:

```ruby
def visit_tag_node(node)
  tag = node.tag
  is_void = is_void_element?(tag)

  # emit open tag
  emit_html(node.tag_location, format_html_tag_open(tag, node.attributes))
  return if is_void

  # emit nested block
  case node.block
  when Prism::BlockNode
    visit(node.block.body)
  when Prism::BlockArgumentNode
    flush_html_parts!
    adjust_whitespace(node.block)
    emit("; #{format_code(node.block.expression)}.compiled_proc.(__buffer__)")
  end

  # emit inner text
  if node.inner_text
    if is_static_node?(node.inner_text)
      emit_html(node.location, ERB::Escape.html_escape(format_literal(node.inner_text)))
    else
      to_s = is_string_type_node?(node.inner_text) ? '' : '.to_s'
      emit_html(node.location, interpolated("ERB::Escape.html_escape((#{format_code(node.inner_text)})#{to_s})"))
    end
  end

  # emit close tag
  emit_html(node.location, format_html_tag_close(tag))
end
```

When HTML is emitted, the corresponding code is not generated immediately.
Instead, each piece of HTML is pushed into an array of pending HTML parts. When
the time comes to flush the pending HTML parts and generate code for them, we
concatenate all static strings together into a single buffer push, while each
dynamic part is escaped and pushed separately.

The P2 compiler does similar work for dealing with other parts of the P2 DSL,
such as template composition, deferred execution, extension tags etc. In
addition there's quite a bit of work around generating a source map that maps
lines from the compiled code to lines in the original source code. When an
exception is raised while generating a template, P2 uses these source maps to
translate the exception's backtrace such that it will point to the original
source code.

## So How Can We Make Ruby Faster than Ruby?

<img src="/assets/yo-dawg-ruby.jpg">

Now that we have an idea of how P2 works, let's look at how I've taken P2
performance from OK to great. When I first released P2, I was quite content with
its performance, since it was significantly faster than Papercraft, and the
benchmark I wrote compared it against ERB. But I haven't taken into account the
fact that I know so little about ERB, and especially about getting the best
performance out of ERB templates.

Luckily, right after first publishing the repository, I got a nice [PR from
byroot](https://github.com/digital-fabric/p2/pull/1) that showed that P2 was not
so fast as I thought. While the discussion above shows how P2 generates code
*now*, at the time it was generating code that was not the best. Here's how the
code P2 generated at the time looked (for the same template example shown
above):

```ruby
->(__buffer__, title:) do
  __buffer__ << "<html><body><h1>#{CGI.escape_html((title).to_s)}</h1></body></html>"
  __buffer__
rescue => e
  P2.translate_backtrace(e)
  raise e
end
```

Now there are a few things in the above code that prevent it from being as fast
as compiled ERB (using the ERB or the ERubi gems):

- Pushing an interpolated string to the buffer is slower than pushing each part
  separately. This is kind of obvious when you take into account the fact with
  an interpolated string, you first need to create a string that receives the
  static and dynamic parts of the interpolated string, and then push that string
  to `__buffer__`.
- The `rescue` clause adds some overhead. This can be especially expensive when
  you have nested templates. If each partial has its own rescue block, that can
  quickly add up to a significant overhead.
- As byroot pointed out, when the generated code is `eval`ed into a Proc,
  literal strings will be default not be frozen, which adds allocation overhead
  and GC pressure.
- As [mrinterweb](https://github.com/mrinterweb) pointed out in a separate
  [PR](https://github.com/digital-fabric/p2/pull/2), escaping HTML with the
  `ERB::Escape.html_escape` is faster than `CGI.escape_html` (just a couple
  percentage points but still...)

So taking all this advice into account, I've rewritten the compiler code to do
the following:

- Separate HTML code generation, such that static HTML strings are contatenated
  and pushed to the HTML buffer once, and any dynamic parts are pushed
  separately.
- Remove the `rescue` clause and instead do the backtrace translation only once
  in `Proc#render`.
- Add the `# frozen_string_literal: true` magic comment at the top of the
  compiled code, so all static HTML content is made of frozen strings, which
  reduces allocation and GC pressure. BTW, when are we going to get frozen
  literal strings by default?
- Switch from using `CGI.escape_html` to `ERB::Escape.html_escape`.

When byroot made his PR, the benchmark looked like this:

```
ruby 3.4.2 (2025-02-15 revision d2930f8e7a) +YJIT +PRISM [arm64-darwin24]
Warming up --------------------------------------
                 erb    31.381k i/100ms
                  p2    65.312k i/100ms
               erubi   179.937k i/100ms
Calculating -------------------------------------
                 erb    314.436k (± 1.3%) i/s    (3.18 μs/i) -      1.600M in   5.090675s
                  p2    669.849k (± 1.1%) i/s    (1.49 μs/i) -      3.396M in   5.070806s
               erubi      1.869M (± 2.3%) i/s  (535.01 ns/i) -      9.357M in   5.008683s

Comparison:
                 erb:   314436.3 i/s
               erubi:  1869118.6 i/s - 5.94x  faster
                  p2:   669849.2 i/s - 2.13x  faster
```

Which showed the P2 still had a lot to improve, as it was almost 3 times slower
than ERubi. (I later also found out how to make ERB compile its templates, its
compiled performance is more or less the same as compiled ERubi.) After the
changes I've implemented here are the updated benchmark results:

```
ruby 3.4.5 (2025-07-16 revision 20cda200d3) +YJIT +PRISM [x86_64-linux]
Warming up --------------------------------------
                  p2   128.815k i/100ms
          papercraft    17.480k i/100ms
               phlex    15.620k i/100ms
                 erb   159.678k i/100ms
               erubi   154.085k i/100ms
Calculating -------------------------------------
                  p2      1.454M (± 2.4%) i/s  (687.59 ns/i) -      7.342M in   5.051705s
          papercraft    173.686k (± 2.7%) i/s    (5.76 μs/i) -    874.000k in   5.035996s
               phlex    155.211k (± 2.5%) i/s    (6.44 μs/i) -    781.000k in   5.035369s
                 erb      1.567M (± 4.2%) i/s  (637.97 ns/i) -      7.824M in   5.000791s
               erubi      1.498M (± 4.2%) i/s  (667.45 ns/i) -      7.550M in   5.048427s

Comparison:
                  p2:  1454360.2 i/s
                 erb:  1567482.7 i/s - 1.08x  faster
               erubi:  1498238.4 i/s - same-ish: difference falls within error
          papercraft:   173686.1 i/s - 8.37x  slower
               phlex:   155211.0 i/s - 9.37x  slower
```

The benchmark shows that P2 is now on par with ERB and ERubi in terms of the
performance of compiled templates (and basically, the generated code for all
three is more or less identical.) I've also added Papercraft and Phlex to show
the difference compilation makes, especially since P2 is really an offshoot of
Papercraft, and the DSL in P2 and Papercraft is almost identical. (Phlex has
also seen some [work](https://github.com/yippee-fun/phlex/pull/917) on template
compilation, but I don't know how far advanced this is.)

As you can see, the compiled approach can be about 10X as fast as the
non-compiled approach. Of course, there's the usual caveat about benchmarks:
it's a very simple template with just two partials and not a lot of dynamic
parts, but this is indicative of the kind of performance you can expect from P2.
As far as I know, P2 is the first Ruby HTML-generation DSL that offers the same
performance as compiled ERB/ERubi.

## Conclusion

What I find most interesting about the changes I've made to code generation in
P2, is that the currently compiled code is more than twice as fast as it was
when P2 first came out, which just goes to show than in fact Ruby is not slow,
it is actually quite fast, you just need to know how to write fast code! (And I
guess this is true for any programming language.)

Hopefully, the Ruby-to-Ruby compilation technique discussed above would be
adpoted for other uses, and for more DSL's. I already have some ideas rolling
around in my head...