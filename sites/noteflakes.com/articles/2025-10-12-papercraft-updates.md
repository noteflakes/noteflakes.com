---
title: "Papercraft update: IRB Support, Bug Fixes, More Speed"
layout: article
---

This last week I was away on a little trip to Paris to attend a
[Paris.rb](https://paris-rb.org/) meetup and meet some friends, so I was less
productive, but still got some stuff done, and still managed to do some work on
[Papercraft](https://papercraft.noteflakes.com/). Here's what's changed:

## Using Papercraft in IRB

Up until now, perhaps the biggest limitation of Papercraft was that you couldn't
use it in an IRB session. That was because Papercraft always *compiles* your
templates, and for that it needs access to the templates' source code. But if
you're defining a template in IRB, where is that source code?

Then, while taking the train to Paris, it occurred to me that maybe IRB keeps
the lines of code you input into it somewhere, and maybe it would be possible to
access those lines of code. It took a bit of digging, but finally I've [found it](https://github.com/digital-fabric/sirop/blob/eec1c528475dbdd0e4ddfe898abb23e10f57a45d/lib/sirop.rb#L82-L86).

As a result, you can now define ad-hoc Papercraft templates right in your IRB
session:

```
sharon@nf1:~$ irb -rpapercraft
irb(main):001> ->{ h1 "Hello, IRB!" }.render
=> "<h1>Hello, IRB!</h1>"
irb(main):002> 
```

It's fun to be able to explore Papercraft templates in IRB, enjoy!

## Some Bug Fixes

I've also had the time to deal with some edge cases I discovered while using
Papercraft:

- Fix compilation of an empty template:

  ```ruby
  -> {}.render #=> ""
  ```

- Raise error on a [void
  element](https://developer.mozilla.org/en-US/docs/Glossary/Void_element) with
  child nodes or inner text:

  ```ruby
  -> { input 'foo' }.render #=> !!! Papercraft::Error
  -> { hr { span } }.render #=> !!! Papercraft::Error
  ```

- Fix `apply` parameter handling when called with a block:

  ```ruby
  a = proc { |*a, **b| body { render_yield(*a, **b) } }
  b = a.apply(:foo, p: 42) { |*c, **d| article { render_yield(*c, **d) } }
  b.render(:bar, q: 43) { |*a, **b|
    h1 a.first, class: b[:p]
    h2 a.last, class: b[:q]
  }
  #=> "<body><article><h1 class=\"42\">foo</h1><h2 class=\"43\">bar</h2></article></body>"
  ```

## HTML Escaping Gets a Speed Boost

Last but not least, I was looking at the source code to
`ERB::Escape.html_escape`, which is the method Papercraft uses to escape all
HTML content (in order to prevent HTML injection). I figured the implementation
could be improved, and opened a [PR](https://github.com/ruby/erb/pull/87) with the proposed change:

> The existing `html_escape` implementation always allocates buffer space (6
> times the length of the input string), even when the input string does not
> contain any character that needs to be escaped.

> This PR modifies the implementation of `optimized_escape_html` to not
> pre-allocate an output buffer, but instead allocate it on the first occurence
> of a character that needs escaping. In addition, instead of copying
> non-escaped characters one by one to the output buffer, continuous non-escaped
> segments of characters are copied using `memcpy`.

> A synthetic benchmark employing the input strings used in the
> `test_html_escape` method in `test/test_erb.rb` shows the modified
> implementation to be about 35% faster than the original...

The PR was merged and a new version of ERB is already
[released](https://rubygems.org/gems/erb). And the best part - this speed up is
available to the entire Ruby ecosystem, not just Papercraft. Everybody that uses
ERB (or its `html_escape` method) will benefit from this!