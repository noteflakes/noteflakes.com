---
title: What's new in Polyphony and Tipi - August 2021 edition
date: 2021-08-26
layout: article
---

The summer is drawing to an end, and with it I bring another edition of Polyphony (and Tipi) news, this time on my own website, where I'll be publishing periodically from now on.

> [Polyphony](https://github.com/digital-fabric/polyphony) is a library for writing highly concurrent Ruby apps. Polyphony harnesses Ruby fibers and a powerful [io_uring](https://unixism.net/loti/what_is_io_uring.html)-based I/O runtime to provide a solid foundation for building high-performance concurrent Ruby apps.

> [Tipi](https://github.com/digital-fabric/tipi) is a new Polyphony-based web server for Ruby. Tipi provides out of the box support for HTTP/1, HTTP/2, and WebSocket. Tipi also provides SSL termination (support for HTTPS) with **automatic certificate provisioning** and automatic ALPN protocol selection.

## From counterpoint to composition

In the last month I've been doing a lot more work on [Tipi](https://github.com/digital-fabric/tipi) than on Polyphony, and most of my work on Polyphony has been just fixing bugs. For me this is a major milestone, as I'm transitioning from working on the low-level stuff, to an actual application that can do something useful. To me this feels a bit like transitioning from writing [counterpoint](https://en.wikipedia.org/wiki/Counterpoint) exercises to composing an actual piece of music.

The Polyphony API is maturing nicely and I hope to be able to make a 1.0 release in the coming weeks. As for Tipi, there's still a lot of work to do in order for it to be useful, and I'll discuss that towards the end of this post.

## Changes in Polyphony

### Support for splicing on non-Linux platforms

The [libev](http://pod.tst.eu/http://cvs.schmorp.de/libev/ev.pod) backend now supports all splicing APIs by emulating the Linux `splice` system call. I've [already written](/articles/2021-06-25-polyphony-june-edition#a-new-api-for-splicing-tofrom-pipes) about splicing and the amazing things that can be done with these APIs. So now they can be used on cross-platform, even if the performance gains are only achievable on Linux.

### Fiber supervision

One of the major advantages of using Polyphony as the basis for concurrent programs is that it implements [structured concurrency](https://en.wikipedia.org/wiki/Structured_concurrency), a programming paradigm that makes it easier to control fiber execution in a highly-concurrent environment. Just imagine writing a program that performs thousands of long-running tasks concurrently. How do you manage that complexity? How do you deal with failures? How can you control any of those concurrent tasks?

Polyphony deals with this problem by adhering to three principles:

1. Fibers are arranged in a hierarchy: a fiber is considered the child of the fiber from which it was spun.
2. A fiber's lifetime is limited to that of its immediate parent. In other words, a fiber is guaranteed to terminate before its parent does.
3. Any uncaught exception raised in a fiber will "bubble up" to its immediate parent, and potentially all the way up to the main fiber (which will cause the program to terminate with an exception, if not handled.)

Here's an example to demonstrate these three principles in action:

```ruby
# Kernel#spin starts a new fiber
@controller = spin do
  @worker = spin do
    loop do
      # Each fiber has a mailbox for receiving messages
      peer, op, x, y = receive
      result = x.send(op, y)
      # The result is sent back to the "client"
      peer << result
    end
  end
  # The controller fiber will block until the worker is done (but notice that
  # the worker runs an infinite loop.)
  @worker.await
end

def calc(op, x, y)
  # Send the job to the worker fiber...
  @worker << [Fiber.current, op, x, y]
  # ... and wait for the result
  receive
end

# wait for the controller to terminate
@controller.await
```

In the above example, we spin a *controller* fiber, which then spins a *worker* fiber. This creates the following hierarchy:

```
main
 |
 +- controller
      |
      +-- worker
```

Now we can just call `#calc` to perform calculations inside the worker:

```ruby
# from the main fiber
calc(:+, 2, 3) #=> 5

# or from another fiber:
f = spin { calc(:**, 2, 3) }
f.await #=> 8
```

But notice what happens when we send an operation that results in an exception:

```ruby
calc(:+, 2, nil)
```
```
Traceback (most recent call last):
        5: from examples/core/calc.rb:7:in `<main>'
        4: from examples/core/calc.rb:8:in `block in <main>'
        3: from examples/core/calc.rb:9:in `block (2 levels) in <main>'
        2: from examples/core/calc.rb:9:in `loop'
        1: from examples/core/calc.rb:12:in `block (3 levels) in <main>'
examples/core/calc.rb:12:in `+': nil can't be coerced into Integer (TypeError)
```

Actually, the exception that was raised inside of the *worker* fiber, has bubbled up to the *controller* fiber. The controller, which was busy waiting for the worker to terminate, has re-raised the exception, which bubbled up to the main fiber. The main fiber, which was waiting for the controller to terminate, has re-raised the exception and has finally exited with an error message and a back trace (you can find the full example [here](https://github.com/digital-fabric/polyphony/blob/master/examples/core/calc.rb)).

The fact that unrescued exceptions bubble up through the fiber hierarchy allow us to control the lifetime of child fibers. Here's one way we can deal with uncaught exceptions in the worker fiber:

```ruby
@controller = spin do
  @worker = spin { ... }
  @worker.await
rescue => e
  puts "Uncaught exception in worker: #{e}. Restarting..."
  # Yes, in Polyphony fibers can be restarted!
  @worker.restart
end
```

Since the controller fiber can intercept any unrescued exception that occurred in its child, we add a rescue block, report the error and then restart the fiber.

Another possibility would be to handle the error at the level of the main fiber, or maybe to handle it locally if it's only about trivial errors, and let more serious exceptions bubble up - it really depends upon the circumstances. The point is that Polyphony allows us to control the lifetime of any fiber anywhere in the fiber hierarchy with a small set of tools that builds on the rubustness of Ruby exceptions: putting `rescue` and `ensure` blocks in the right places will already do 99% of the work for us.

But what if we want to automate the handling of errors? What if we just want things to continue working without us needing to manually write `rescue` blocks? Enter fiber supervision.

### Inspired by Erlang

The new fiber supervision mechanism in Polyphony is greatly inspired by Erlang [supervision trees](https://adoptingerlang.org/docs/development/supervision_trees/). While Erlang processes are not organised hierarchically, Erlang provides a [supervisor behaviour](http://erlang.org/doc/design_principles/sup_princ.html) that allows expressing hierarchical dependencies between processes.

While a lot of the functionality of Erlang supervision trees is already included in Polyphony by virtue of the structured concurrency paradigm, the Erlang supervisor behaviour allows automating the handling of error conditions. This is what I set to solve in the new fiber supervision API.

The new `Kernel#supervise` method can be used to supervise one or more fibers. By default, it does nothing more than just waiting for all supervised fibers to terminate. But it can also be used to automatically restart fibers once they have terminated, or restart them only when an exception occurred, or to perform other work when a fiber is terminated (for example, writing to a log file).

Going back to our example, here's how we can use the controller fiber to supervise the worker fiber:

```ruby
@controller = spin do
  @worker = spin { ... }
  supervise(@worker, restart: :always)
end
```

The call to `Kernel#supervise` tells the controller fiber to monitor the worker fiber and to restart it always once it terminates, ignoring any exceptions. Alternatively, we can tell the controller to restart the worker only when an exception occurs:

```ruby
supervise(@worker, restart: :on_error)
```

We can also define a custom behavior by passing a block that will be called when the worker fiber terminates:

```ruby
supervise(@worker) do |fiber, result|
  log_exception(result) if result.is_a?(Exception)
  fiber.restart
end
```

## Staying in the loop: the advantages of fiber supervision

In my work on Polyphony and on Tipi I have discovered a few programming patterns that I find very interesting:

- When using Polyphony you write a lot of loops. A good bunch of those are infinite loops! Take for example the worker fiber above.
- When developing a concurrent app using Polyphony, any uncaught exception might cause the entire process to terminate, since Polyphony never allows exceptions to be lost.

If we look at Tipi, a Polyphony app that can be used to serve HTTP/S on multiple ports, we'll have a separate fiber listening for incoming connections on each port. When a connection is accepted, we spin a new fiber in order to handle the new connection concurrently:

```ruby
http_listener = spin do
  while (conn = http_server.accept)
    spin { handle_client(conn) }
  end
end

https_listener = spin do
  while (conn = https_server.accept)
    spin { handle_client(conn) }
  end
end
```

Since the client handling fibers are spun from the listener fibers (either `http_listener` or `https_listener`), they are considered the children of those fibers. If any exception is raised in a client handling fiber and is not rescued, it *will* bubble up to the listener fiber and will cause it to terminate with the exception.

In addition, the listeners themselves might raise exception when accepting connections - these can be system call errors, I/O errors, OpenSSL errors (for the HTTPS listener) etc. We'd like an easy way to catch these errors. One way would be to just do this with a `rescue` block:

```ruby
...

https_listener = spin do
  loop do
    conn = https_server.accept
    spin { handle_client(conn)
  rescue => e
    puts "HTTPS accept error: #{e.inspect}"
  end
end
```

This is a possibility, but we need to do it manually for each fiber, and we risk adding a lot of rescue blocks (some of them can even be for a specific class of exception) everywhere, an error-prone methodology that can prove problematic if overdone.

Instead, we can use the `Kernel#supervise` API provided by Polyphony to make sure our infinite loops (i.e. our listener fibers) continue running, even when an exception occurs. Thus we can embrace the Erlang moto: "Let it crash." We let it crash, and then we restart it. Here's how we can employ this using fiber superivision:

```ruby
http_listener = spin(:http) { ... }
https_listener = spin(:https) { ... }
# If specific fibers are not specified, #supervise will supervise all of the
# current fiber's children.
supervise do |fiber, result|
  if result.is_a?(Exception)
    puts "Fiber #{fiber.tag} terminated with exception: #{result}. Restarting..."
    fiber.restart
  end
end
```

In this way we ensure that any *uncaught* exception from one of the listeners or their children will not slip through and stop the server from functioning. Any listener that has stopped because of an exception will just be restarted. And applying this to our controller example above:

```ruby
@controller = spin do
  @worker = spin do
    loop do
      peer, op, x, y = receive
      result = x.send(op, y)
      peer << result
    end
  end
  supervise(@worker, restart: :always)
end

def calc(op, x, y)
  # Send the job to the worker fiber...
  @worker << [Fiber.current, op, x, y]
  # ... and wait for the result
  receive
end

supervise(@controller, restart: :always)
```

### Bug fixes and other changes 

Here's a list of other, smaller changes and fixes in Polyphony:

- Prevent possible segfault in the io_uring backend by GC marking read/write buffers [when cancelling an I/O operation](https://github.com/digital-fabric/polyphony/commit/c6a842f281ff3649d678300dc58883dbe32a6373). When cancelling an IO operation, the Ruby process might have already moved on while the kernel is still accessing the associated buffers before finally cancelling the operation. In order to prevent a possible segfault in case a GC cycle kicks in immediately after cancellation, I have introduced a mechanism to GC mark the buffers used until the operation has been cancelled in the kernel as well.
- [Improve fiber monitoring](https://github.com/digital-fabric/polyphony/commit/ebb64e7b3e5a1e32deaec8a8f3d6e8aa8366c7ca): in preparation for work on fiber supervision, the `Fiber#monitor` implementation has undergone a lot of simplification and made much more robust.
- `Fiber#attach` was [renamed](https://github.com/digital-fabric/polyphony/commit/406619347e7957d3b0077626589f1c6e131ddb94) to `Fiber#attach_to`.
- Fixed [linking of operations](https://github.com/digital-fabric/polyphony/commit/0aaaf7fd663472d539b08612ab1edeeb3079bb91) in `Backend#chain`.
- Fixed [missing default value](https://github.com/digital-fabric/polyphony/commit/722ad0170f2afe776d07e93ebcb4d26b4b17804c) in `#readpartial` for socket classes.
- Fixed [removing child fiber](https://github.com/digital-fabric/polyphony/commit/029074ad5a3d2a76caec322aebe216b6c88ff720) from parent's children list when terminated.
- Reset backend runqueue and other state [after forking](https://github.com/digital-fabric/polyphony/commit/e7d91451ae871dca6029bceb2a6933d16e6b6c27).
- Fix [compilation on Ruby 3.0](https://github.com/digital-fabric/polyphony/commit/da2cbdce4e8f462585fd5ff86ae29cc67306c6e5).

## Changes in Tipi

The Tipi server is progressing nicely. I've been running it in production over the last few months, and while it's still a long way from providing a stable, easy-to-use API for other developers, in terms of features and functionality it's already got 90% of the features expected from a modern web server: support for HTTP/1 *and* HTTP/2, SSL termination, support for WebSocket and streaming responses, support for serving static files and of course running Rack apps. Tipi is also able to dynamically provision SSL certificates using an [ACME](https://en.wikipedia.org/wiki/Automated_Certificate_Management_Environment) provider (such as [Let's Encrypt](https://letsencrypt.org/)), though this feature is still work in progress.

Following is a summary of the big changes in Tipi this month.

### H1P - a new HTTP/1 parser

I've hinted before about writing an HTTP/1 parser made for Tipi. Well the work is more or less done, and I've released the parser as a separate project called [H1P](https://github.com/digital-fabric/h1p). What sets this parser apart is the fact that it is completely blocking. While other parsers (at least the ones I know of) provide a callback-based API, where you register callbacks for different events, and then feed the parser with data and wait for those callbacks to be invoked, by contrast H1P provides a blocking API that's much easier to use:

```ruby
conn = server.accept
parser = H1P::Parser.new(conn)
headers = parser.parse_headers
body = parser.read_body
handle_request(headers, body)
```

Yes, that's it (for the most part). And, the beauty of this parser is that you don't even need Polyphony in order to use it. In fact you can use it in a "normal" threaded server (spawning a thread for each connection), and you can use it in conjunction with the new [fiber scheduler](https://rubyapi.org/3.0/o/fiber/schedulerinterface) introduced in Ruby 3.0.

The H1P parser is implemented in [less than 750 lines of C](https://github.com/digital-fabric/h1p/blob/main/ext/h1p/h1p.c), has zero dependencies and supports chunked encoding and `LF`/`CRLF` line breaks, has [hard limits](https://github.com/digital-fabric/h1p/blob/main/ext/h1p/limits.rb) on token length for minimizing server abuse, and is transport agnostic - you can have it read from any source, even sources that are not IO objects:

```ruby
data = ['GET ', '/foo', " HTTP/1.1\r\n", "\r\n"]
parser = H1P::Parser.new { data.shift }

parser.parse_headers
#=> { ':method' => 'GET', ':path' => '/foo', ... }
```

I intend to keep on working on H1P, notably on the following:

- Add conformance and security tests.
- Add ability to parse HTTP/1 responses (for implementing HTTP clients.)
- Add ability to splice the request body into an arbitrary fd (Polyphony-specific.)
- Improve performance. In a synthetic benchmark, H1P is ~15% slower than the callback-based [http_parser.rb](https://github.com/tmm1/http_parser.rb) gem, which uses the *old* node.js HTTP/1 parser. In actual use in Tipi, I've seen the throughput actually improve with H1P, and I think this is attributable to the fact that when converting from a callback-based API to a blocking API (as I do in Tipi) there's quite a bit of overhead involved in buffering the requests, and all the more so when needing to deal with [HTTP pipelining](https://en.wikipedia.org/wiki/HTTP_pipelining).

In addition to that, I also plan to implement a similar H2P project for handling HTTP/2 connections.

### Automatic SSL certificate provisioning

If there's one feature that can be a game changer for a Ruby web server, it's automatic SSL certificate provisioning. Tipi already does SSL termination, and that makes it possible to use Tipi without any load balancer or reverse proxy in front of it, since it can deal with incoming HTTPS connections all by itself. But automatic SSL certificates take this autonomy to the next level: you don't even have to provide a certificate for Tipi to use. Tipi will just take care of it all by itself, by dynamically provisioning a certificate from an [ACME](https://en.wikipedia.org/wiki/Automated_Certificate_Management_Environment) provider, such as [Let's Encrypt](https://letsencrypt.org/) or [ZeroSSL](https://zerossl.com/).

Imagine not having to set up Nginx, Apache or Caddy as a reverse proxy in order to run your web app. You just run Tipi (preferably with port-forwarding, so you don't need to deal with binding to privileged ports) and point it at your Rack app. This is what I'm aiming to achieve in the near future.

So automatic certificates already work in Tipi. In fact, this very website, which I've put together a few weekends ago, already uses automatic certificates. While it works, there's still a lot of details to take care of: testing, handling of failures, adding more ACME providers, and finally coming up with a simple API for configuring automatic certificates.

### Other changes

In addition to the above big new features, I've also worked on the following:

- Fixed upgrading to HTTP/2 [with a request body](https://github.com/digital-fabric/tipi/commit/86c648a13199c79818793b5f49648c30216b644c).
- Start work on CLI interface. Nothing to announce for the moment, but what I'm aiming for is a command line tool that can be used to serve static files in any directory, serve a rack app, or a custom app using Tipi's API, with automatic certificates.

## What's next for the Polyphony ecosystem?

In the last few years I've been creating a set of Ruby gems that I call [Digital Fabric](https://github.com/digital-fabric/), with the moto: "Software for a better world." I believe in empowering small developers to build lightweight, autonomous digital systems to solve specific needs. The Digital Fabric suite already includes tools for working with [SQLite databases](https://github.com/digital-fabric/extralite), creating [HTML templates](https://github.com/digital-fabric/rubyoshka), and [managing dependencies](https://github.com/digital-fabric/modulation), in addition to [Polyphony](https://github.com/digital-fabric/polyphony) and  [Tipi](https://github.com/digital-fabric/tipi).

I'm a long-time Ruby programmer, and to date my most substantial contribution to the Ruby community is [Sequel](http://sequel.jeremyevans.net/), of which I'm the original author. The same spirit that guided me in creating Sequel is the one that's currently guiding me in working on the Digital Fabric suite of tools: create simple and powerfull APIs that make developers happy and that feel like natural extensions of the Ruby programming language. I believe Polyphony and Tipi have the potential to unleash a new wave of creativity in the Ruby community!

Here's some of the things I intend to work on in the near future:

- Further work on the H1P parser, as discussed above.
- Start work on H2P - a library for dealing with HTTP/2 connections.
- Continue work on automatic certificates in Tipi.
- Prepare Polyphony for a 1.0 release.
- Setup a websites for both Polyphony and Tipi.
- Continue work on [Impression](https://github.com/digital-fabric/impression), a new experimental web framework, which incidentially I'm using for this site. It's just a sketch for the moment, but I have a bunch of ideas that that I'd like to test, but it's still too early to tell if it will turn into a real project.
- And finally, prepare Tipi for a first public release once the CLI tool is good enough.
