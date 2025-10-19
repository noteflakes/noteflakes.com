---
title: Roll Your Own
---

As discussed earlier, Papercraft templates are defined as lambdas, and
consequently they are completely self-contained and can be used in any context
and in any situation. This also means that you can use it in conjunction with
any web framework, and in any place in your app's code.

That said, you might encounter problems when trying to integrate Papercraft
templates with helper functions that might be available to you when using ERB
templates in frameworks such as Rails or Hanami. Other than that, there's really
no limit to how you can use Papercraft for your HTML templates.

## Keep it Pure

Papercraft templates, like all Ruby lambdas, are also closures, which means they
capture the local binding where they are defined, and therefore have access to
any local variable, as well as the local receiver (a.k.a. `self`). This means
that you can reference any local or instance variable, or explicitly call
methods on self inside your templates.

However, it is better to use explicit arguments as discussed in the [Writing
Templates](/docs/02-basic-usage/01-writing-templates) section, as this greatly
increases the reusability of your templates. This also makes it easier to
eventually refactor your code:

```ruby
# instead of this:
def greet
  Papercraft.html {
    h1 "Hello, #{@name}!"
  }
end

# do this:
def greet
  Papercraft.html(
    ->(name) {
      h1 "Hello, #{name}!"
    },
    @name
  )
end
```

The same goes for calling methods on `self`:

```ruby
# instead of this:
def template
  -> {
    h1 self.title
  }
end

# do this:
TEMPLATE = ->(ctx:) {
  h1 ctx.title
}

def template
  Papercraft.apply(TEMPLATE, ctx: self)
end
```
