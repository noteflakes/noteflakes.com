---
title: How Papercraft Works
---

Papercraft employs some innovative techniques for achieving a rendering
performance equal to compiled ERB templates. Just like in ERB/ERubi/Herb,
Papercraft *compiles* the templates you write into highly-optimized code. Let's
look at a simple example:

```ruby
->(name) {
  div {
    h1 {
      a "Hello, #{name}!", href: '/welcome'
    }
  }
}
```

From the point of view of the Ruby runtime, running the code in this template
and generating HTML from it will necessitate some implicit buffer (because it
doesn't appear anywhere in the template code), and all those tag methods (`div`,
`h1` and `a`) to be defined somewhere, either in the local scope of the
template, or in the `Kernel` module. Doing this is not only very intrusive, but
also slow. So how does Papercraft do it?

## Template Compilation

The first step in compiling a template is to read its source code and transform
it into an AST (abstract syntax tree). This is done by reading the source
location of the template lambda, reading the source file and parsing the
lambda's source code using Prism, the new Ruby source code parser shipped with
Ruby.

The template's AST is then transformed, and each receiver-less method call is
mutated into a special `TagNode` that signifies that an HTML tag is to be
emitted into an output buffer.

Finally, a special-purpose compiler converts the transformed AST back to source
code, coalescing consecutive HTML snippets into optimized buffer concatenation
calls, to finally produce the following code:

```ruby
->(__buffer__, name) {
  __buffer__.<<("<div><h1><a href=\"/welcome\">").
            .<<(ERB::Escape.html_escape(
              ("Hello, #{name}!")
            ))
            .<<("</a></h1></div>")
  __buffer__
}
```

> (The above code was edited to add whitespace for better readability.)

The compiled version of the template adds `__buffer__` as its first argument,
but otherwise keeps the same arguments as in the original template code. The
static parts (the tag names and any literal values) are coalesced into a single
`push` operation, while the dynamic parts are passed through `html_escape` in
order to properly escape them and prevent HTML/Javascript injection. Finally the
buffer is returned as the return value.

So, when you call `#render` on the template, Papercraft performs the compilation
automatically (on the first invocation), calls the compiled code with a string
buffer, and returns the buffer.
