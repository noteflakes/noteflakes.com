---
title: "Unrolled Code"
layout: article
---

The other day I was looking at a little project called
[grubby](https://git.btxx.org/grubby/), a minimal static site generator for git
repos, written in Ruby. The style is quite interesting: it feels solid and unapologetic:

```ruby
def fill_template(template, page_title, root_prefix)
  template
    .gsub("{{title}}", escape_html(page_title))
    .gsub("{{root}}", root_prefix)
    .gsub("{{stylesheet}}") { STYLESHEET }
    .gsub("{{build_date}}", BUILD_DATE)
end
```

Nothing is particularly optimized, it just uses available tools to do its work:

```ruby
def write_page(page_path, page_title, root_prefix = "")
  FileUtils.mkdir_p(File.dirname(page_path))

  header = fill_template(HEADER_TEMPLATE, page_title, root_prefix)
  footer = fill_template(FOOTER_TEMPLATE, page_title, root_prefix)

  File.write(page_path, header + yield + footer)
end
```

After running `git ls-tree` and collecting the filenames in the repository, it
generates an HTML page for each file. Looking at the code examples above we can
discern a primitive templating system: there's `#fill_template` for
replacing place-holders in the template with values, there's a
`#render_markdown` helper function, there's the composition of the inner HTML
with the header and footer HTML in `#write_page`.

The header and footer are stored in separate files, but where are the templates
for the actual page content? A bit further down, we find them. Here's the index
page:

```ruby
...
write_page(File.join(output_dir, "index.html"), repo_name) do
  ...
  page_html = "<header>\n<p><strong>#{escape_html(repo_name)}</strong></p>\n"
  page_html += "<p>#{escape_html(repo_description)}</p>\n"
  page_html += "<p><code>#{escape_html(clone_command)}</code></p>\n</header>\n"
  ...
  page_html
end
...
```

This code has a very specific shape: it's a series of operations that stuff
strings into a buffer. In fact, this code looks very similar to the kind of code
that will actually run when you use
[Papercraft](https://github.com/digital-fabric/papercraft) or
[ERB](https://github.com/ruby/erb) for generating HTML from templates. Both ERB
and Papercraft compile the templates into optimized Ruby code that emits
snippets of HTML into a buffer.

I find it interesting that the code remains very readable, even though it's very
low level. There are of course many different ways to write this kind of code.
We could use a heredoc with string interpolation:

```ruby
page_html = <<~HTML
  <header>\n<p><strong>#{escape_html(repo_name)}</strong></p>
  <p>#{escape_html(repo_description)}</p>
  <p><code>#{escape_html(clone_command)}</code></p>\n</header>
HTML
```

There's also the *optimized* way that avoids interpolation and therefore double
copying of strings:

```ruby
page_html <<
  "<header>\n<p><strong>" << escape_html(repo_name) <<
  "</strong></p>\n<p>" << escape_html(repo_description) <<
  "</p>\n<p><code>" << escape_html(clone_command) <<
  "</code></p>\n</header>\n"
```

A bit less readable, but somewhat faster. Both ERB and Papercraft compile code
into this form. Just for kicks, how would a corresponding ERB template look?

```erb
<header>
  <p><strong><%= escape_html(repo_name) %></strong></p>
  <p><%= escape_html(repo_description) %></p>
  <p><code><%= escape_html(clone_command) %></code></p>
</header>
```

This looks pretty nice! It's just HTML with some interpolated strings in it. And
how about Papercraft?

```ruby
header {
  p { strong(repo_name) }
  p(repo_description)
  p { code(clone_command) }
}
```

Everything is compressed down to a minimal syntax. What's interesting is that in
the end, when you render this template, Papercraft will actually compile it into
code that looks a lot like [grubby](https://git.btxx.org/grubby/):

```ruby
__buffer__
  .<<("<header><p><strong>").<<(ERB::Escape.html_escape((a)))
  .<<("</strong></p><p>").<<(ERB::Escape.html_escape((b)))
  .<<("</p><p><code>").<<(ERB::Escape.html_escape((c)))
  .<<("</code></p></header>")
```

So going back to the grubby code, it was interesting to see this style of
coding, which basically "unrolls" the code that would have been generated if a
templating tool like ERB or Papercraft was used. But it also reminded me of
another code base I was looking at recently, that of
[Herb](https://github.com/marcoroth/herb), which is a gem with a set of tools
for working with ERB templates. Here's an excerpt:

```ruby
# from Herb::Engine#initialize:
...
@context = Visitor::Context.new(
  file_path: properties[:filename],
  project_path: properties[:project_path],
  options: context_options(properties),
  resolver: properties[:resolver],
  **(properties[:context] || {})
)
    
@bufvar = properties[:bufvar] || properties[:outvar] || "_buf"
@escape = properties.fetch(:escape) { properties.fetch(:escape_html, false) }
@escapefunc = properties.fetch(:escapefunc, @escape ? "__herb.h" : "::Herb::Engine.h")
@attrfunc = properties.fetch(:attrfunc, @escape ? "__herb.attr" : "::Herb::Engine.attr")
@jsfunc = properties.fetch(:jsfunc, @escape ? "__herb.js" : "::Herb::Engine.js")
@cssfunc = properties.fetch(:cssfunc, @escape ? "__herb.css" : "::Herb::Engine.css")
@src = properties[:src] || +""
@chain_appends = properties[:chain_appends]
@buffer_on_stack = false
@parser_options = properties.fetch(:parser_options, default_parser_options).transform_keys(&:to_sym)
...
```

The entire `Herb::Engine#initialize` method is about 65 LOC! And the individual
lines themselves stretch to the right edge of your editor window. I ran `cloc`
on the code and was really taken by surprise:

```
~/playground/herb $ cloc --exclude-dir test --include-ext rb,rs,c,ts .
...
github.com/AlDanial/cloc v 2.06  T=2.55 s (359.5 files/s, 66052.1 lines/s)
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
TypeScript                     549          19777           4641          65383
Ruby                           161           6838           3255          20728
Rust                           141           5531            338          20397
C                               66           4649            148          16809
-------------------------------------------------------------------------------
SUM:                           917          36795           8382         123317
-------------------------------------------------------------------------------
...
```

OK, so the Typescript stuff is probably not relevant to the present discussion,
but still, 20KLOC of Ruby, and another 37KLOC of C/Rust extensions. For
comparison, ActiveRecord is about 46KLOC (not including tests). The entire Rails
codebase is about 120KLOC of Ruby (again, not including tests). Herb just became
the default template renderer in Rails 8.2.

Herb's template compiler code looks beautiful:

```ruby
def generate_output
  optimized_tokens.each do |type, value, context, escaped|
    case type
    when :text
      @engine.send(:add_text, value)
    when :code
      @engine.send(:add_code, value)
    when :expr, :expr_escaped
      indicator = indicator_for(type)

      if context_aware_context?(context)
        @engine.send(:add_context_aware_expression, indicator, value, context)
      else
        @engine.send(:add_expression, indicator, value)
      end
    when :expr_block, :expr_block_escaped
      @engine.send(:add_expression_block, indicator_for(type), value)
    when :expr_block_end
      @engine.send(:add_expression_block_end, value, escaped: escaped)
    when :chain
      @engine.send(:add_expression_result, value)
    end
  end
end
```

This method is basically a router inside of a loop. it converts data into method
calls. Again, this kind of functionality could have been hidden behind a DSL,
but here we have the entire logic for this algorithm laid out very explicitly in
front of our eyes. Another example:

```ruby
def self.js(value)
  value.to_s.gsub(/[\\'"<>&\n\r\t\f\b]/) do |char|
    case char
    when "\n" then "\\n"
    when "\r" then "\\r"
    when "\t" then "\\t"
    when "\f" then "\\f"
    when "\b" then "\\b"
    else
      "\\x#{char.ord.to_s(16).rjust(2, "0")}"
    end
  end
end
```

And another:

```ruby
def add_code(code)
  terminate_expression

  if code.include?("=begin") || code.include?("=end")
    @src << "\n" << code
    @src << "\n" unless code.end_with?("\n")
  else
    @src << " " unless code.match?(/\A\n+\z/)
    @src << code

  if Helpers.comment?(code) || Helpers.heredoc?(code)
    @src << "\n" unless code[-1] == "\n"
  else
    @src << ";" unless code[-1] == "\n"
  end

  @buffer_on_stack = false
end
```

It's just logic expressed in the purest way possible. The code that we're
looking into here is charged with transforming an ERB template into a piece of
Ruby source code containing an optimized renderer for the given template. The
optimized source code is painstakingly put together from little bits and pieces,
according to the structure of the template. If take the same HTML template from
the grubby example above, ERB/Herb would have generated the following code:

```ruby
# edited for formatting
_erbout = +''
_erbout.<< "  <header>\n  <p><strong>".freeze
_erbout.<<(( escape_html(repo_name) ).to_s); _erbout.<< "</strong></p>\n  <p>".freeze
_erbout.<<(( escape_html(repo_description) ).to_s); _erbout.<< "</p>\n  <p><code>".freeze
_erbout.<<(( escape_html(clone_command) ).to_s); _erbout.<< "</code></p>\n</header>\n".freeze
_erbout
```

Note the similarities: we're dealing with constructing a string, we're mostly
doing just one type of action, and the action is repeated. This is what unrolled
code is about: clarity, discipline, optimization, and grouping like actions
together. Let's take a look at another codebase:

```ruby
def emit_wildcard_childless_root_code(buffer, root_path)
  emit_code_line(buffer, '->(path, params) {')
  if root_path != '/'
    re = /^#{Regexp.escape(root_path)}(\/.*)?$/
    emit_code_line(buffer, "  return if path !~ #{re.inspect}")
  end
  emit_code_line(buffer, "  @dynamic_map[#{root_path.inspect}]")
  emit_code_line(buffer, '}')
end
```

This is from [Syntropy](https://github.com/digital-fabric/syntropy), which is
the web framework that's driving this website, and the code excerpt is part of
its routing tree compiler. The idea is to take a tree-like data structure
describing the apps's directory structure and files, and compile it into an
optimized router lambda that can deal with parametric and wildcard routes.

The resulting router code would look something like the following:

```ruby
->(path, params) {
  entry = @static_map[path]; return entry if entry
  segments = path.split("/")
  return nil if (segments[1] != "syntropy")
  case (s = segments[2])
  when "api"
    return @dynamic_map["/syntropy/api+"]
  when "mod"
    case (s = segments[3])
    when "bar"
      return @dynamic_map["/syntropy/mod/bar"]
    end
  when "params"
    case (s = segments[3])
    when s
      params["foo"] = s
      case (s = segments[4])
      when nil
        return @dynamic_map["/syntropy/params/[foo]"]
      end
    end
  end
  return nil
}
```

Like with ERB/Herb, the Syntropy code generates a complex piece of code by
putting together strings containing parts of expressions. The
`#emit_wildcard_childless_root_code` method could also have been written as
follows:

```ruby
def emit_wildcard_childless_root_code(buffer, root_path)
  re = /^#{Regexp.escape(root_path)}(\/.*)?$/
  emit_code_block <<~EOF
    ->(path, params) {
      #{ 'return if path !~ #{re.inspect}' if root_path != '/' }
      @dynamic_map[#{root_path.inspect}]
    }
  EOF
end
```

This is much clearer, but still, the code for generating the conditional return
in the middle there is a bit hairy. What if we had a DSL for generating Ruby
code? In Elixir you can define macros that expand into code with a pair of tools
called quote/unquote. In fact, a lot of Elixir's language features (even stuff
like `if` and `case`) are implemented using macros. When a macro is used, the
macro definition is expanded in place, it's like *parametric code*. This idea,
like all good ideas, comes from Lisp, where there's no distinction between data
and code. What if we had that in Ruby?

```ruby
def wildcard_childless_root_code(root_path)
  quote { 
    ->(req) {
      unquote {
        if root_path != '/'
          re = /^#{unquote(Regexp.escape(root_path))}(\/.*)?$/
          quote { return if path !~ unquote(re) }
        else
          :__nop__
        end
      }
      @dynamic_map[unquote(root_path)]
    }
  }
end
```

The `#quote` method returns the AST of the given block. The `#unquote` is used
to inject arbitrary values into the code template. In this example, we
conditionally inject a piece of Ruby code also expressed with a nested `quote`
block, that interpolates a regular expression. The final call to `#unquote`
injects the value of root_path into the generated code.

Notice the mechanics of quote/unquote: with `#quote`, obviously we're putting
code inside quotes, and with `#unquote` we're jumping temporarily out of the
quotes in order to perform some computation and inject the result into the
quoted code. The expression passed to `unquote` is evaluated at *compile-time*.
This allows us to conditionally include pieces of code in the template. And
since unquote always returns an AST (or `:__nop__` for nothing), we can use it
to compose ASTs together:

```ruby
def compile_html(ast)
  html_parts = []
  flusher = -> {
    return :__nop__ if html_parts.empty?
    
    html = html_parts.join; html_parts.clear
    quote(locals: [:__buffer__]) { __buffer__ << unquote(html) }
  }
  quote(locals: [:__buffer__, *ast.parameters]) {
    unquote(
      mutate(ast) { |node, transform|
        if html_tag?(node)
          emit_html(node, transform, html_parts, flusher)
        else
          [flusher.(), *transform.(node)]
        end
      }
    )
    unquote(flusher.())
    __buffer__
  }
end
```

Here's an attempt to apply the idea of quote/unquote to compiling Papercraft
templates. This method takes the template AST, and returns a mutated AST, where
tag method calls are translated to strings being emitted to a buffer. But since
we want to have the same optimized form of bunching together static strings and
separating out the dynamic strings, we introduce some compile-time state (the
`html_parts` buffer), and a `flusher` closure that generates the actual code
that emits static strings to the buffer. This design lets us support recursion
in `emit_html`, so we can do stuff like `div { p { a 'Home' } }`, since the
state is passed as arguments.

## Some complementary tools

Suppose we have this quote/unquote functionality ready to let us generate code
progrmatically. We still need a few more tools to be able to create code.
Consider the following:

```ruby
def memoize(*methods)
  methods.each do |m|
    ast = Sirop.to_ast(method(m))
    memoized = mutate(ast, ast.body => quote {
      (@memo ||= {})[unquote(m)] = begin; unqoute(ast.body); end
    })
    eval(Sirop.to_source(memoized))
  end
end
```

([Sirop](https://github.com/digital-fabric/sirop) is a little gem I wrote to
help work with Prism ASTs.)

`#mutate` works by creating a copy of the AST, letting you replace any node on
the tree with another. In this case, we're implementing a momoized version of a
method by replacing the method body with a wrapped version of itself, where we
inject the memo key and the original method body into the code. I think this
example demonstrates the strength of this approach, it kinda feels magical!

Another way to work with `#mutate` is by passing it a block that returns either
the original node, or a different node in case of a mutation:

```ruby
l1 = ->(x) { 42 }
mutated = mutate(Sirop.to_ast(l1)) { |n|
  n.is_a?(Prism::IntegerNode) ? quote { 43 } : n
}))
l2 = eval(Sirop.to_source(mutated))
l2.() #=> 43
```

What about keywords? What if, for example, we wanted to programmatically add a
`when` clause inside of a `case` statement?

```ruby
quote {
  case foo
    unquote(
      bar ? quote { when :bar; p 'baz' }
    )
  end
}
```

This is invalid syntax, and while Prism will parse this, the AST would contain a
`MissingNode`, and will otherwise be deformed. Here's a solution that doesn't
feel too inelegant:

```ruby
def make_case_expr(entry)
  quote {
    __.case unquote(entry[:name]) {
      quote {
        unquote entry[:options].map { |o|
          quote { __.when unquote(o); add_option(unquote(o)) }
        }
        __.else; raise 'Invalid option'
      }
    }
  }
end
```

This lets us construct `case` statements programmtically, and we can extend this
principle to basically any keyword, like `rescue`:

```ruby
def make_fatal_lambda(body, *fatal_errors)
  quote {
    -> {
      __.begin {
        unquote(body)
        unquote(fatal_errors.map { |t|
          quote { __.rescue(unquote(t) => e) { puts 'BOOM!'; exit!(42) } }
        })
      })
    }
  }
end

make_fatal_lambda(quote { 1 / 0 }, ZeroDivisionError).() #=> BOOM!
```

I find that a functional approach to coding goes very well when working with
ASTs. We treat ASTs as immutable objects, and if we need to change a node
anywherer on the AST, we can use `#mutate` which creates a copy with the
requisite changes. If we're generating complex code, as we do in Papercraft,
Syntropy, or ERB, we can split the code generation logic into multiple methods,
each of which prepares a distinct part of the code, and returns an AST. This
allows us to create arbitrarily complex pieces of code by composing ASTs
together. Let's take a real use case. Here's the template for an ActiveRecord
migration, used by a generator. Yes, Rails uses ERB to generate code:

```erb
class <%= migration_class_name %> < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :<%= table_name %><%= render_table_with_dom_id %> do |t|
<% attributes.each do |attribute| -%>
<% if attribute.password_digest? -%>
      t.string :password_digest<%= attribute.inject_options %>
<% elsif attribute.token? -%>
      t.string :<%= attribute.name %><%= attribute.inject_options %>
<% else -%>
      t.<%= attribute.type %> :<%= attribute.name %><%= attribute.inject_options %>
<% end -%>
<% end -%>
<% if options[:timestamps] -%>
      t.timestamps
<% end -%>
    end
  end
end
```

How would it look with quote/unquote? Let's find out:

```ruby
version = ActiveRecord::Migration.current_version
quote do
  __.class(unquote(migration_class_name) < ActiveRecord::Migration[unquote(version)]) {
    def change
      create_table unquote(table_name) do |t|
        unquote attributes.map do |attribute|
          opts = attribute.inject_options
          if attribute.password_digest?
            quote { t.string unquote(:"password_digest#{opts}") }
          elsif attribute.token?
            quote { t.string unquote(:"#{attribute.name}#{opts}") }
          else
            # note use of unquote as method name
            quote { t.send(unquote(attribute.type), unquote(:"#{opts}") }
          end
        end
        unquote(
          options[:timestamps] ? quote { t.timestamps } : :__nop__
        )
      end
    end
  }
end
```

Not very pretty, I admit, but maybe a little refactoring, splitting the code
into distinct parts, would make it better:

```ruby
def attribute_ast(attribute)
  opts = attribute.inject_options
  if attribute.password_digest?
    quote { t.string unquote(:"password_digest#{opts}") }
  elsif attribute.token?
    quote { t.string unquote(:"#{attribute.name}#{opts}") }
  else
    quote { __.call(t, unquote(attribute.type), unquote(:"#{opts}") }
  end
end

def timestamps_ast(options)
  options[:timestamps] ? quote { t.timestamps } : :__nop__
end

version = ActiveRecord::Migration.current_version
quote do
  __.class(unquote(migration_class_name) < ActiveRecord::Migration[unquote(version)]) {
    def change
      create_table unquote(table_name) do |t|
        unquote attributes.map { attribute_ast(it) }
        unquote(timestamps_ast(options))
      end
    end
  }
end
```

Oh yes this is much better, as we can now see the shape of the generated code!
One more example, fitting for the title of this article:

```ruby
def rewrite_block_param(ast, v) {
  block_param_name = ast.parameters.parameters.requireds[0].name
  mutate(ast) { |n, t|
    if n in Prism::LocalVariableReadNode(name: block_param_name)
      unquote(v)
    end
  }
}

def unroll(o, &block)
  block_ast = Sirop.to_ast(block)
  o.map { |v| rewrite_block_param(block_ast, v) }
end

ast = quote {
  -> {
    unquote unroll(%w{foo bar baz}) { |v| p v }
  }
}
unrolled_printer = eval(Sirop.to_source(ast))
```

Here we use `#mutate` to change the body of a given block such that all
references to the block argument will be replaced with an arbitrary value, such
that the actual code of `unrolled_printer` would be:

```ruby
-> {
  p 'foo'
  p 'bar'
  p 'baz'
}
```

## Walking the Fine Line of Abstraction

This morning I was looking at a vibe-coded [port of
Campfire](https://github.com/tobi/campfire-once-ruby-ractor) from Rails to plain
Ruby (with ractors). This is an interesting project, and I think it demonstrates
pretty well the [performance costs of
Rails](https://static.lutke.dev/KTK6Vb/campfire-ruby-explainer/)' abstractions.
With Rails, we choose developer happiness at the expense of machine happiness.
But the results show that Ruby is actually pretty fast. OK, not as fast as Rust,
but in many cases faster than Go!

And the code itself is interesting - a lot of unrolled code for sure, but
generated by an LLM:

```ruby
def dispatch(request)
  ...
  if (verb == "GET" || verb == "HEAD") && (file = Assets.file(path))
    return static(file, request)
  end
  return health(request) if path == "/up"
  if path.start_with?(STORAGE_PREFIX)
    # ActiveStorage controllers; the proxy ones stream (ActionController::Live).
    return Front.finish_response(request, Storage.call(request, path, query), live: path.include?("/proxy/"))
  end

  body = nil
  if verb == "POST" && request.headers["content-type"]&.to_s&.start_with?(FORM)
    body = (request.body&.join || +"").force_encoding(Encoding::UTF_8)
    if (i = body.index("_method="))
      m = body[i + 8, 6].to_s[/\A[a-z]+/i]
      verb = m.upcase if m && %w[PATCH PUT DELETE].include?(m.upcase)
    end
  elsif verb == "POST" && request.headers["content-type"]&.to_s&.start_with?(MULTIPART)
    # Rails forms with file inputs carry _method as a multipart part.
    body = (request.body&.join || +"").force_encoding(Encoding::BINARY)
    if (i = body.byteindex(METHOD_PART)) && (j = body.byteindex("\r\n\r\n", i))
      m = body.byteslice(j + 4, 6).to_s[/\A[a-z]+/i]
      verb = m.upcase if m && %w[PATCH PUT DELETE].include?(m.upcase)
    end
    body.force_encoding(Encoding::UTF_8)
  end
  ...
end
```

Look at the style. The lines stretch to the right, and the code itself is
dealing with tiny details, no abstractions here, just pure algorithms (and lots
of branching!) The `dispatch` method is about 45 lines long, and could have been
easily refactored into a few separate methods that each does a single thing.

An experienced programmer would probably have a blast refactoring this code,
there are lots of opportunities in there to make it more readable, more
maintainable, even snappier than it already is. This is obviously unrolled code,
but other parts of the code base do use metaprogramming. For example, let's look
at the router config code, which may look familiar to a Rails developer:

```ruby
Campfire::ROUTES = Campfire::Router.new do
  get "/", to: "WelcomeController#show", format: false

  get "/first_run", to: "FirstRunsController#show"
  post "/first_run", to: "FirstRunsController#create"

  get "/session/new", to: "SessionsController#new"
  post "/session", to: "SessionsController#create"
  delete "/session", to: "SessionsController#destroy"
  get "/session/transfers/:id", to: "Sessions::TransfersController#show"
  patch "/session/transfers/:id", to: "Sessions::TransfersController#update"
  put "/session/transfers/:id", to: "Sessions::TransfersController#update"
  ...
end
```

So there's a DSL here, using the builder pattern:

```ruby
class Router
  ...
  
  def initialize(&block)
    @groups = Hash.new { |h, k| h[k] = [] }
    instance_eval(&block)
  end

  %w[GET POST PATCH PUT DELETE].each do |verb|
    define_method(verb.downcase) do |pattern, to:, defaults: nil, format: true|
      add(verb, pattern, to, defaults, format)
    end
  end

  ...
end
```

This is just the syntactic sugar, but it's the `#add` method that does the work
of computing and storing the route information:

```ruby
def add(verb, pattern, to, defaults, format)
  controller, action = to.split("#")
  names = []
  src = pattern.gsub(%r{:(\w+)|\*(\w+)|\.|@}) do
    if $1
      names << $1
      "([^/.]+)"
    elsif $2
      names << $2
      "(.+)"
    else
      Regexp.escape($&)
    end
  end
  src << "(?:\\.([a-z0-9]+))?" if format
  first = pattern.split("/")[1] || ""
  first = "" if first.start_with?(":")
  @groups[first] << Route.new(verb, Regexp.new("\\A#{src}\\z"), names.freeze,
    controller, action.to_sym, defaults&.freeze)
end
```

The actual routing of incoming requests is done in `#recognize`:

```ruby
def recognize(verb, path)
  verb = "GET" if verb == "HEAD"
  slash = path.index("/", 1)
  first = slash ? path[1, slash - 1] : path[1..]
  dot = first.index(".")
  first = first[0, dot] if dot
  route_in(@groups[first], verb, path) || route_in(@fallback, verb, path)
end
```

Here we can see that what this routing DSL does (as in many cases) is to convert
code into data. All routing configuration is stored in `@groups`, and the work
of actually routing requests (done in `#recognize`) is all about consulting the
routing data. But with quote/unquote we can convert data into code, as we saw
above in the Syntropy router example. Here's the original `#route_in` method:

```ruby
def route_in(routes, verb, path)
  return nil unless routes
  routes.each do |r|
    next unless r.verb == verb
    m = r.regex.match(path) or next
    params = r.defaults ? r.defaults.dup : {}
    r.names.each_with_index { |n, i| params[n] = m[i + 1]&.force_encoding(Encoding::UTF_8) }
    return [r, params, m[r.names.size + 1]]
  end
  nil
end
```

See that loop in there? We can unroll it using quote/unquote:

```ruby
def compile_groups
  @groups = @groups.transform_values { make_route_in_proc(it) }
end

def make_route_in_proc(routes)
  eval Sirop.to_source quote {
    ->(verb, path) {
      unquote routes.map { |r|
        quote {
          if (unquote(r.verb) == verb && (m = unquote(r.regex.match(path))))
            params = unquote(r.defaults ? r.defaults.dup : {})
            unquote(r.names).each_with_index { |n, i| params[n] = m[i + 1]&.force_encoding(Encoding::UTF_8) }
            return [routes[unquote(routes.index(r))], params, m[unquote(r.names.size + 1)]]
          end
        }
      }
    }
  }
end
```

With this, we've converted each route group to a custom-made piece of code.
Notice the frequent use of unquote - this allows us to change any references to
the `r` iterator variable from attribute lookups into literal values! And we can
do this safely because the routing configuration is immutable. The only place
where we need to do a bit more work is in the return statement, where we need to
also return a reference to the specific route. We do this by calling `routes[]`
where the subscript is hard-coded using `#unquote`.

## Taking Metaprogramming to the Next Level

Ruby is famous for its productivity and simplicity, and Ruby programmers have
wholeheartedly embraced its metaprogramming facilities in the quest for
*developer happiness*. Tools such as `eval`, `instance_eval`, and
`define_method` let us create beautiful abstractions that make our code more
readable and arguably easier to maintain. All those Rails idioms, they're
catchy, they make the intent clear, it's almost as if they've become part of the
Ruby syntax!

The quote/unquote mechanism I'm proposing here doesn't exist yet in Ruby, but if
it ever materializes, I think it would open a whole new world of possibilities
for Ruby. Such tools will allow us to create better abstractions without paying
the associated performance overhead. They might make it possible to express new
ideas, new idioms, and new techniques for manipulating Ruby code.
