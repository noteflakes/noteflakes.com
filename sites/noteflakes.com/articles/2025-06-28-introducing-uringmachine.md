---
title: Introducing UringMachine
layout: article
---

[UringMachine](https://github.com/digital-fabric/uringmachine) is a new Ruby gem
for performing concurrent I/O using io_uring and Ruby fibers. In UringMachine
I've implemented all the lessons I've learned from my previous attempts at
bringing io_uring to Ruby:
[Polyphony](https://github.com/digital-fabric/polyphony), a comprehensive gem
providing io_uring functionality, structured concurrency, and monkey-patching
for the Ruby standard library; and [IOU](https://github.com/digital-fabric/iou),
a low level async API for using io_uring from Ruby.

Here are some of those lessons:

## Monkey-patching

I've defended monkey-patching before, but my stance now is more nuanced.
Frankly, it's a big pain to maintain, because the Ruby stdlib is evolving, and
in some cases it's really an excercise in futility. So, UringMachine doesn't
really touch the standard IO classes, it just doesn't use them. UringMachine
works with plain file descriptors:

```Ruby
require 'uringmachine'

machine = UM.new
fd = machine.open('foo.bar', UM::O_RDONLY)
buf = +''
ret = machine.read(fd, buf, 1 << 16)
puts "read #{ret} bytes: #{buf.inspect}"
machine.close(fd)
```

Now, at first sight this might look like a really clumsy way to do I/O in Ruby,
but there's more than meets the eye in the above example. A second example will
make things a bit clearer:

```Ruby
filenames = ['foo.bar', 'bar.baz', 'baz.foo']
content_map = {}

MAX_READ_LEN = 65536

# A neat abstraction to do what IO.read(fn) does
def read_file(machine, fn)
  fd = machine.open(fn, UM::O_RDONLY)
  buf = +''
  loop do
    # the -1 means append to buffer
    ret = machine.read(fd, buf, MAX_READ_LEN, -1)
    return buf if ret < MAX_READ_LEN
  end
ensure
  machine.close(fd) if fd
end

fibers = filenames.map do |fn|
  machine.spin do
    content_map[fn] = read_file(fn)
  rescue SystemCallError
    puts "Failed to read #{fn}"
  end
end
machine.join(*fibers)
p content_map: content_map
```

So yes it's much lower level than IO's `#read` and `#write` methods, but what we
gain here is easy launching of concurrent (a.k.a. asynchronous) operations. In
the above example, three files are read concurrently in three separate fibers by
calling `#spin` (just like in Polyphony). Each fiber opens the given filename,
reads the contents until EOF and then puts the content in a content map.
Meanwhile the main fiber calls `#join` in order to wait for the three spun
fibers to terminate.

## The "Everything but the Kitchen Sink" Approach

Polyphony was a library that was trying to do a lot of things, such as
structured concurrency, on-the-fly file compression (using pipes), HTTP parsing
and chunked transfer encdoing, and an actor API with message passing.

The result was a big gem (~2.7KLOC of Ruby, plus ~6KLOC of C) with a very big
surface area, lots of classes, lots of money-patches. In comparison,
UringMachine is currently at about 200LOC of Ruby, plus ~2.7KLOC of C.

UringMachine does not try to do everything that's related to concurrency.
Instead, it focuses on providing the basics, which you can then use to build out
the abstractions you want, such as message passing between fibers, structured
concurrency etc.

## A Simpler, More Robust Implementation

Polyphony has started as a wrapper around libev, and has evolved with time to
provide an alternative backend that uses io_uring instead of libev. UringMachine
was built from the beginning as a Linux-only, io_uring-only library. Its design
is also in many ways simpler than that of the Polyphony backend.

I still haven't run benchmarks comparing UringMachine to Polyphony, but from
using UringMachine for running a webserver, it looks about the same, which means
*fast*.

## A New Ecosystem

Polyphony is but one of a bunch of Ruby gems I've been writing for fun and
profit. Some of those tools were written just to explore what's possible in
Ruby, and some of those are being actively used in production on my clients'
websites.

But UringMachine does not offer the same (theoretical) level of integration with
the Ruby ecosystem as Polyphony. It just does I/O its own way. It does not
interfere with other gems or the way Ruby does I/O, but any I/O that does not go
through UringMachine means that the parts that do use UringMachine for I/O and
concurrency may be waiting for stock Ruby I/O operations to complete before
being able to complete their own I/O operations.

Thus, to do anything useful, UringMachine will need to be accompanied by other
gems that create an ecosystem around it.

## TP2 - a New Webserver for Ruby

[TP2](https://github.com/noteflakes/tp2) is a new webserver based on
UringMachine. It is the continuation of my work on
[Tipi](https://github.com/digital-fabric/tipi). TP2 also has a much simpler
design than Tipi (and a much smaller codebase). TP2 uses UringMachine for
managing I/O and concurrency.



## Syntropy - a New Web Framework for Ruby

A third part of the new ecosystem is
[Syntropy](https://github.com/noteflakes/syntropy), a new web framework I've
been working on. It, too, is a continuation of the work I've been doing in
[Impression](https://github.com/digital-fabric/impression).

Like Impression, Syntropy is a filesystem-based router. The routes of the app
are defined by the directory and file structure of your app. So for example,
HTTP requests to `/foo/bar` will be routed to `site/foo/bar.rb`. Syntropy can
also serve static files and markdown files.

Dynamic routes are served by Ruby files that are called modules. Each module
exports an request handler, which can be in the form of a custom class, a
[Papercraft](https://github.com/digital-fabric/papercraft) template, or a simple
Proc:

```ruby
# here's the simplest possible route module:
export ->(req) { req.respond('Hello, world!') }
```

Other features in Syntropy:

- Define middleware with `_hook.rb` modules
- Define custom error handlers with `_error.rb` modules
- Support for working with collections of markdown files, e.g. a list of blog
  articles.
- Support for clean URLs (i.e. without the file extension) for HTML, markdown
  and module files.
- Development mode with automatic route reloading on file change.

Future directions for Syntropy include:

- Tools for deploying your web app to any Linux server using Docker Compose
- Tools for creating a skeleton web app.
- A data modeling layer based on SQLite databases, for use in: caching, logging,
  web analytics and more.
- The ability to integrate applets in a webapp, so for example an applet can
  include subroutes defined in a separate directory (such as a different gem's
  directory), for ease of integration.

## Future Work on UringMachine

UringMachine is still missing some features. Here are some of the things I
intend to add in the near future:

- Support for more io_uring ops, such as `splice`, `sendto`, `recvfrom`
- Support for polling
- Some abstractions for easily reading and writing entire files.
- Support for SSL I/O.

## Conclusion

UringMachine, TP2 and Syntropy represent a new direction in my work. My aim is
to build tools that fit my way of writing software, and that are tailor-made for
my workflow and my preferences. As such, I'm trying to avoid feature creep, and
instead focus on just adding (or changing) the stuff I need in order to execute
for my clients.

Hopefully, someone else may find these projects interesting enough to use them,
but it's really more about scratching my own itch. The proof is right here on
this website, which is made with the above tools.
