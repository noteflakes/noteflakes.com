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
them however you want. Papercraft also makes it very easy to compose templates:
creating layouts, partials and components is almost trivial!

Papercraft is designed for developer happiness, but it does not compromise on
rendering performance. In fact, you 

does not skimp on 
rendering performance, in fact it is just as fast as compiled ERB or ERubi.
