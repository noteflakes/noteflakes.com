Q---
title: "Rethinking modularity in Ruby applications"
layout: article
---

I wrote [recently](/articles/2026-06-13-syntropy) about
[Syntropy](https://github.com/digital-fabric/syntropy), a new Ruby web framework
I'm working on (it runs [this
site](https://github.com/noteflakes/noteflakes.com)). Syntropy's design is based
around the idea of file-based routing, which means that the source files for
route handlers (i.e. controllers) that make up the app are organized and named
according to the app's URL namespace. I also discussed the way Syntropy loads
the different source files (referred to as modules), and I'd like to discuss
this a bit more in detail.

## Code Organization in Ruby on Rails

Now, if you're a Rails developer, you know that Rails' approach to code
organization is based on auto-loading of the different source files that make up
the app, performed by the [Zeitwerk](https://github.com/fxn/zeitwerk) gem. This
approach automates the loading of dependencies, using the directory structure as
a representation of the app's namespace (i.e. classes and modules).

In the Rails approach, all of the app's classes and modules are global, nested
according to the app's directory structure. There's no need to explicitly
`require` dependencies, since any constant reference will be automatically
loaded, and this means the dependencies between different parts of app are
implicit.

This approach works very well, as long as you're organizing your code in classes
that follow certain conventions in terms of naming and file locations. A big
advantage is that you don't need to explicitly `require` the different source
files in your app. Instead, they're loaded automatically as constants are
referenced by running code. Zeitwerk even supports automatic reloading of
changed files in development mode.

One important disadvantage of the Rails approach is that you're bound to the
idea of one class per file, and of course the names for the different classes
must match the source file's location. This means that if you move a source file
to a different directory, you'll also need to rename the class to match its new
location.

A further disadvantage is that since everything is global, you might risk
touching or referencing classes you shouldn't, and since dependencies are
implicit, those "references by error" may go unnoticed and cause some unexpected
(read: undefined) behaviour. For example, since any singleton object (and
singleton objects are quite handy in web apps) is defined as a global, your code
might accidentally access that global object, or even change its state.

In my experience I have found that when an app reaches a certain level of
complexity, and its source code is split across a large number of files,
explicitly expressing dependencies between different parts of the source code is
a tremendous help to understanding the structure of the code and the
relationships of the different parts of the app.

I have also come to appreciate the possibility of expressing interfaces not only
in terms of classes and modules, but also with procs/lambdas (i.e. closures) and
other singleton objects. In many cases you'll need to access some "global"
service or state object, such as a database connection pool, a background job
store, a mailer object, or even a configuration hash. Being able to do that with
explicit references means that you don't need to rely on these objects being
available as global constants. This in turn makes it easier to implement
dependency injection, and it also greatly simplifies testing.

## Code Organization in Syntropy

Syntropy is based on the idea that the app's directory structure reflects its
URL namespace. For example, a simple blog app would have a directory structure
resembling the following:

```
files               URLs
=====               ====
+ app/
  + _lib/
    + storage.rb
  + _layout/
    + default.rb
  + index.rb        /
  + about.rb        /about
  + posts/
    + [id]/
      + index.rb    /posts/[id]
      + edit.rb     /posts/[id]/edit
      + index.rb    /posts
      + new.rb      /posts/new
```

The example above consists of both controller code (which maps to URLs) and
internal dependencies which are typically put in directories such as `_lib` or
`_layout` (any directory or file whose name starts with an underscore is
considered internal and is not exposed by the Syntropy router).

How do those different source files get loaded by the application? In the case
of controllers, they're loaded automatically when the server receives a request
with a URL that matches the source file location. For example, a `GET /posts`
request will be routed to `app/posts/index.rb`.

A second principle in Syntropy is that all dependencies are explicit. In order
to load any dependency inside the app, we call `import`. For example, here's how
the posts index controller may look:

```ruby
# app/posts/index.rb
@storage = import '/_lib/storage'
@layout = import '/_layout/default'
@template = @layout.apply { |posts:, **|
  posts.each { |post|
    article {
      h1 { a post.title, href: post.url }
      p post.body
    }
  }
}

export ->(req) {
  posts = @storage.get_all_posts
  req.respond_html(@template.render(posts:))
}

```

In the above example, we import two dependencies, a `@storage` object which
serves as the model interface, and a `@layout` object which serves as a
[Papercraft](github.com/digital-fabric/papercraft) layout template. We then
create a template that renders a list of posts, and finally we export the
controller lambda, which takes an incoming HTTP request, retrieves the list of
posts from `@storage` renders an HTML response by rendering `@template`.

Since we can export any object from a module, and that will serve as its
*value*, we might express the layout module as follows:

```ruby
# app/_layout/default.rb
export template {
  html {
    head { ... }
    body {
      render_children
    }
  }
}
```

In this module the layout template (a Papercraft template) is the actual
interface of the module, such that each time you `import` it, you get the same
object that was exported. Here's how the storage module might look:

```ruby
# app/_lib/storage.rb
export self

def get_posts
  ...
end

...
```

In the case of the storage module, we export the module itself as a singleton,
which lets us call any of its methods:

```ruby
storage = import '/_lib/storage'
storage.get_posts
```

Loading code in this way has some important advantages:

- Loading the module code has zero side effects on global state: all constants,
  and instance variables are completely local to the module's context, and do
  not leak to the global context.
- A module's interface can be any object, not just a class, which makes it so
  much easier to use singletons.
- Dependencies are explicit, which makes it easier to understand how the
  different pieces of code fit together and where everything is located.
- The fact that each module is completely self-contained and doesn't "leak" into
  the global namespace makes it much easier to test it in separation.
- It also makes it much easier to implement code reloading. Since all
  dependencies are known at runtime, we can track calls to `import`, and if any
  module's underlying file has changed, we can simply discard the old module,
  reload the new code, then recursively reload all of its reverse-dependencies.

## Injecting State into Modules

Since each module is `eval`d in a separate, anonymous context, this means we can
also easily inject state into the module when loading it. This is especially
useful for injecting an environment hash (holding the app's configuration), or
other app concerns that may be used by the module, such as the app object
itself, the underlying `UringMachine` instance, or any other global service.
This too may simplify the task of unit testing those modules. This is done by
setting instance variables that are available to the module. Here's how a
Syntropy module may access the app's configuration:

```ruby
# app/_lib/mailer.rb
require 'my_mailer'

export MyMailer.new(@env[:config][:smtp_server])
```

Here, we access `@env`, which is injected into the module when it's loaded. And
of course, we could easily inject a custom `@env` object if we wanted to, for
testing purposes.

## How Module Loading Works in Syntropy

In the previous article presenting Syntropy, I discussed the basic mechanics of
how Syntropy loads modules. Let's look in more detail at how Syntropy achieves
this. The entire Syntropy [module loader
code](https://github.com/digital-fabric/syntropy/blob/main/lib/syntropy/module_loader.rb)
is completely self-contained and does not depend on any other part of Syntropy,
it just needs to be provided with a few dependencies that are passed to the
modules being loaded.

```ruby
# Greatly simplified version:
class ModuleLoader
  def initialize(env)
    @env = env
    @app_root = env[:app_root]
    @modules = {} # maps ref to module entry
  end

  def load(ref)
    ref = "/#{ref}" if ref !~ /^\//
    if !(entry = @modules[ref])
      entry = load_module(ref)
      @modules[ref] = entry
    end
    entry[:export_value]
  end

  private

  def load_module(ref)
    fn = File.expand_path(File.join(@app_root, "#{ref}.rb"))
    code = read_file(fn)
    env = @env.merge(module_loader: self, ref: clean_ref(ref))
    mod = ModuleContext.new(env, code, fn)

    {
      fn: fn,
      module: mod,
      export_value: mod.__export_value__,
    }
  end
end
```

The module loader is initialized with an `env` object representing the app's
environment (including its configuration). The `#load` method reads the source
code for the module, then instantiates a `ModuleContext` object that's going to
serve as the context in which the module's source code is going to run:

```ruby
# Greatly simplified version:
class ModuleContext
  def initialize(env, code, fn)
    @env = env
    @module_loader = env[:module_loader]
    @ref = env[:ref]
    instance_eval(code, fn)
  end

  private

  def export(v)
    @__export_value__ = v
  end
  
  def import(ref)
    @module_loader.load(ref)
  end
end
```

The entire mechanism of module loading is represented in these few lines: we
create a module context instance, evaluate the source code using
`#instance_eval`, and the `import`/`export` methods are defined as private
methods and allow explicit dependencies between the different modules, and the
usage of *any* object as a module interface.

Here's how we may use this in a testing situation:

```ruby
class FooTest < Minitest::Test
  def setup
    @module_loader = ModuleLoader.new(
      # injected environment hash
      {
        app_root: File.join(__dir__, 'fixtures')
        foo: 'foo'
      }
    )
  end

  def test_foo_module
    foo = @module_loader.load('foo')
    refute_nil foo

    # suppose the foo module has an #env method:
    assert_equal 'foo', foo.env[:foo]
  end
end
```

As you can see in the code above, the fact that there's no global state makes
writing tests so much easier: our tests do not have a side-effects (at least in
terms of changing the global namespace), and we can inject arbitrary values into
the environment passed to the loaded modules. Also, since the interfaces for the
`ModuleLoader` and `ModuleContext` classes are so minimal, it's easy to extend
or compose them into more complex behaviours, or simply to override the stock
behaviour.

## Breaking Out of the OOP Jail

If there's one thing I adore about Ruby is the fact that it's so flexible and so
amenable to different styles of writing code and to different techniques. The
common approach to writing Ruby code is based on sticking to more or less strict
OOP principles: encapsulation, inheritance, code organized into classes, and
classes organized into a single global topology.

But there are other ways to write Ruby code - and a lot of times, expressing a
functionality as a closure (i.e. a Proc) is so much more powerful, expressive
and concise than the usual approach. This is especially true when we're dealing
with building apps on top of a web framework. The framework expects the app's
controllers to have a certain shape, but instead of expressing those controllers
as classes, we can express them as procs:

```ruby
# The Rails way:
class PostsController < ApplicationController
  def index = ...
  end
end

# The Syntropy way
export ->(req) { ... }
```

There are important differences here, some of them were discussed above, and the
question of boilerplate is actually the least interesting one. The Rails
controller is globally named, while the Syntropy controller is anonymous. In
Rails, an instance of the controller is allocated for each request and its
entrypoint method is then called. In Syntropy the controller *is* the entrypoint
that's called on each request (with the request as an argument), and there's no
object allocation when the controller is invoked.

Also, the fact that controllers are procs gives us both freedom to organize our
code as we want, and an almost magical ability to dynamically generate custom
controllers, using a variety of techniques. Lastly, using closures (i.e. procs)
as units of modularity encourages us to create clean interfaces. When the
surface area of a certain functionality is reduced to a single method interface
(i.e. `#call`), you start thinking differently about how to build your app.

Take a look at a controller from the [blog
example](https://github.com/digital-fabric/syntropy/tree/main/examples/blog) in
the Syntropy repository. This is a barebones site that allows you to view, add,
edit and delete blog posts:

```ruby
# app/posts/index.rb
@posts = import '_lib/posts'
@layout = import '_layout/default'
@template = @layout.apply {
  ...
}

export dispatch_by_http_method

def get(req)
  posts = @posts.get_all
  req.respond_html(@template.render(posts:, flash: req.flash))
end

def post(req)
  data = req.get_form_data
  title = req.validate(data['title'], String, /.+/)
  body = req.validate(data['body'], String, /.+/)
  id = @posts.create(title, body)

  req.flash[:notice] = 'Post was successfully created.'
  req.redirect("posts/#{id}")
end

```

We start by importing dependencies and assigning them to instance variables:
`@posts` is the model, `@layout` is the Papercraft template used as layout, and
`@template` generates HTML to show the list of posts. We then export an
expression: `dispatch_by_http_method`. This is actually a method call, here's
its implementation:

```ruby
def dispatch_by_http_method
  ->(req) {
    sym = req.method.to_sym
    raise Syntropy::Error.method_not_allowed if !respond_to?(sym)

    send(sym, req)
  }
end
```

Here we get to taste some of the power of using procs as closures: we generate a
closure that knows how to dispatch a request based on the HTTP method by calling
the corresponding Ruby method on itself. It is automatically bound to the module
context (i.e. `self`), and with just a few lines of code we expressed a very
common behaviour - the request will be dispatched to the method corresponding to
the request's HTTP method, and if the method is not implemented, a `METHOD NOT
ALLOWED` status code is returned to the client.

So once we call `dispatch_by_http_method` to generate the controller's
entrypoint, all that's left is to implement the handlers for the HTTP methods we
want to accept, namely `GET` and `POST`:

```ruby
export dispatch_by_http_method

def get(req)
  ...
end

def post(req)
  ...
end
```

We could in fact use the same technique to implement a Rails-style controller
(it will need to be a wildcard route because a Rails controller actually handles
multiple different URLs by default):

```ruby
# app/posts+.rb
export dispatch_action

def index(req) = ...

def show(req) = ...

def new(req) = ...

# €tc...
```

Now take a look at the code above. To quote a famous Rails person, "look at all
the things I'm not doing!" I'm not defining any classes, I'm not namespacing
anything, I'm defining global constants. The only reference to this code is its
location in the app's directory structure, and the `dispatch_by_action`
directive dynamically creates a closure that wraps our code, along with a little
bit of logic to dispatch the request to the correct method.

So, while we still organize our controller logic using methods, the glue code,
is implemented using procs/closures. Now I'm not saying that all Ruby code
should look like this. Of course there are many situations where the classic OOP
approach is beneficial. This is especially true for Ruby gems, where we need to
have clearly defined APIs, and also some type information. But in an
app-on-top-of-a-framework situation, where the app code is driven by the
framework, coding the app's entrypoints as closures brings with it multiple
benefits: less boilerplate, clearer dependencies, more dynamic behaviour, and
expressivity.

I think there's still a lot to be discovered in writing Ruby code in a more
functional style. In the last few years I've been exploring just that - bringing
a more functional approach to Ruby. Some of my work has lead to the development
of [Papercraft](github.com/digital-fabric/papercraft), which brings a functional
approach to HTML templating. Syntropy now brings a functional approach to web
controllers. And I think the same could also be done for models, which I hope to
discuss in a future article.
