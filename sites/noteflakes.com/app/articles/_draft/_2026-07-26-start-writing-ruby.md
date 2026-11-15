---
title: "On Dave Thomas's Start Writing Ruby"
layout: article
---

I recently watched Dave Thomas' talk from the recent RubyConf Austria. He talked
about the overuse of classes in Ruby code, and that in many cases the
use of classes is incorrect, superfluous and in bad taste. I quite agree with
this. In the last few years, as I have been transitioning to a more *functional*
approach to programming in Ruby, this evolution in the way I code has led to a
smaller number of classes, and also a flatter taxonomy of object classes in my
different software projects.

While the patterns Dave Thomas identifes in his talk are endemic to Ruby code at
large, and might be labeled as bad practices (aka anti-patterns), there are some
important nuances and exceptions that should be discussed, and that's what I'd
like to do in this post.

## OOP is Not About Classes

Dave makes the observation that object oriented programming is not, contrary to
common belief, about classes. It is about messaging




## The Builder Pattern

Let's say we want to develop a simple DSL for expressing database schema
migrations. The traditional technique for implementing a DSL is using the
[builder pattern](/?): we construct an object which will receive method calls
and will build the target data (in our case, a set of schema migration
operations). Here's how such a DSL might be used:

```ruby
schema {
  initial { |db|
    db.execute 'create table foo (bar)'
  }
  version('2026-07-13') { |db|
    db.execute 'create table bar (baz)'
  }
}
```

Here's how it might be implemented:

```ruby
class SchemaDSLBuilder
  def initialize
    @migrations = {}
  end

  def run(&)
    instance_eval(&)
    @migrations
  end

  private

  def initial(&block)
    @migrations['0000'] = block
  end

  def version(key, &block)
    @migrations[key] = block
  end
end

def schema(&)
  SchemaDSLBuilder.new.run(&)
end
```

In Dave Thomas's book this is a no no - it's named after a design pattern, and
it's invalid after new. On the other hand, since we use `instance_exec` that
means we need to intercept calls to `#initial` and `#version`, and that means we
need to define those methods. But again, we can do the same with a module:

```ruby
module SchemaDSL
  def run(&)
    @migrations = {}
    instance_eval(&)
    @migrations
  end

  private

  def initial(&block)
    @migrations['0000'] = block
  end

  def version(key, &block)
    @migrations[key] = block
  end
end

def schema(&)
  Object.new.extend(SchemaDSL).run(&)
end
```

So we remplaced the `SchemaDSLBuilder` class with a module called `SchemaDSL`,
we removed the `#initialize` method, and instead of creating an instance of a
custom class, we create an instance of `Object`, extend it with the DSL methods,
and call `run`. Does this improve the code quality? I'm not sure. The code
difference is quite subtle, maybe it's just a matter of style.

## Modules as Traits

I do think, however, that embracing a design where modules are used as traits,
and the object class taxonomy itself reflects only the application entities we
need to model and not the abstract classes of the underlying framework. Take the
quintessential ActiveRecord class definition:

```ruby
class Post < ActiveRecord::Base
end
```

We could express it as:

```ruby
class Post
  include ActiveRecord::Base
end
```

If we embrace this style, we can actually change the way we think about how
different object types are implemented. By using modules instead of abstract
base classes, we can decouple the object behaviour from the class taxonomy. That
means we are free to design our class taxonomy without basing it on some
framework base class. And for each class we can pick the behaviours we need:

```ruby
# Beaviours
module Renderable
  def render(canvas) = raise NotImplementedError
end

module Composite
  def render(canvas)
    {
      type: :composite,
      entries: @entries ? @entries.map { it.render(canvas) } : []
    }
  end

  def add(entry)
    (@entries ||= []) << entry
  end
end

class Composite

class Rectangle
  
  
  def render(canvas)
    
end

```


## Ruby Modules are Awesome



Instead of writing those enormous
classes with thousands of lines, we can separate different aspects of an
object's behaviour into different modules, and include those modules in the
application's classes.
