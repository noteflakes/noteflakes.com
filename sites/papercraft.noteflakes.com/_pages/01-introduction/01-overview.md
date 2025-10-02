---
title: Overview
---

Papercraft is a templating engine for dynamically producing HTML in Ruby apps.
Papercraft templates are expressed as Ruby lambdas, leading to easier debugging,
better protection against HTML injection attacks, and better code reuse.

Papercraft templates can be composed in a variety of ways, facilitating the
usage of layout templates, and enabling a component-oriented approach to
building web interfaces of arbitrary complexity.

In Papercraft, dynamic data is passed explicitly to the template as block/lambda
arguments, making the data flow easy to follow and understand. Papercraft also
lets developers create derivative templates using full or partial parameter
application.

## Why Papercraft?

Why should you write your HTML templates in Ruby? All of us know how to generate
HTML with ERB, and ERB is pretty cool! But with Papercraft, you don't need to do
the constant mental switching between HTML syntax and Ruby syntax. As you'll see
there's also no need to put each template in a separate file. You can organize
your templates however you want. Papercraft also makes it very easy to compose
templates: creating layouts, partials and components is trivial:

```ruby
-> {
  div {
    h1 "Hello, world!"
  }
}.render
#=> "<div><h1>Hello, world!</h1></div>"
```

Papercraft is designed for developer happiness, but it does not compromise on
rendering performance. In fact, Papercraft offers best-in-class performance,
equal to the performance of compiled ERB/ERubi/Herb templates!

With features such as explicit template arguments, automatic HTML escaping, and
builtin support for rendering markdown, Papercraft provides a comprehensive
solution to your HTML templating needs.