---
title: Getting Started
---

Papercraft is easy to install and use. You can use Papercraft with any web
framework, be it Rails, Hanami, or Roda, or even with any web framework. As
you'll see, there's no special API for integrating Papercraft into whatever
framework you're using. You can directly render Papercraft templates in any
context, anywhere in your code.

## Installing Papercraft

To install Papercraft, run the following command in your project directory:

```bash
$ bundle add papercraft
```

That's all there is to it.

## Generating your first template

Here's a simple way to get started with Papercraft. First, create a file called
`papercraft_test.rb` somewhere in your project, and copy the following code into
it:

```ruby
# frozen_string_literal: true

require 'papercraft'

hello = ->(name) {
  h1 "Hello from #{name}!"
}

puts hello.render('Papercraft')
```

Then run the test code and you should see the following output:

```bash
$ ruby papercraft_test.rb
<h1>Hello from Papercraft</h1>
```

You might want to experiment a bit with changing your test program: you can
change `h1` to `p`, you can pass a different parameter to the template instead
of `'Papercraft'`, or you can simply continue to the next section in these docs.