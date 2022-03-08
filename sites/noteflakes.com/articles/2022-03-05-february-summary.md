---
title: My Open Source Ruby Gems - February 2022 Report
layout: article
---

> I'm an independent software developer working mostly on Ruby apps. In the line
> of my work, I've developing various [open-source
> projects](https://github.com/digital-fabric) spanning the gamut from low-level
> concurrency constructs to database and frontend concerns. If you care about my
> work, please consider [becoming a sponsor on
> Github](https://github.com/sponsors/ciconia).

Here's a summary of my open-source work in February:

## Polyphony - fiber-based concurrency for Ruby

[Polyphony](https://github.com/digital-fabric/polyphony) got [a lot of my
attention](https://github.com/digital-fabric/polyphony/commits?author=ciconia&since=2022-01-31&until=2022-03-01)
in the last month, and I spent a lot of time working on mostly low-level
details:

- Added supported for IPv6 addresses.
- Improved handling of process signals.
- Improved behaviour of SSL sockets.
- Improved error handling in forked processes.
- Improved compatibility of drop-in fiber-aware `Queue` implementation with
  stock Ruby API.
- Overhauled the tracing subsystem for tracing backend events. This feature lets
  developers track what's happening at the backend level - scheduling and
  switching fibers, polling for I/O completion etc. This tracing subsystem will
  eventually be used to build an interface for monitoring the behaviour of
  fibers in live Polyphony-based apps, similar to the [Erlang
  observer](https://www.erlang.org/doc/apps/observer/observer_ug.html), or the
  new [tokio-console](https://tokio.rs/blog/2021-12-announcing-tokio-console)
  for Rust.
- Refactored, cleaned up and documented a whole lot of code.

The documentation effort is still ongoing, and hopefully I'll be able to create
a new website for the project in the coming months. My plan is to be able to put
out a version 1.0 sometime in 2022.

## Extralite - A fast Ruby gem for working with SQLite3 databases

[Extralite](https://github.com/digital-fabric/extralite) has also been a
principal focus of my attention in February. I worked on two big features:

- Prepared statements - now users of Extralite can create prepared statements
  which can then be used multiple times for querying, with the same flexible API
  that lets you get results in a variety of ways (hash, array, single column,
  single row, or single value):

  ```ruby
  require 'extralite'

  db = Extralite::Database.new('my.db')
  stmt = db.prepare('select count(*) from order_items where order_id = :order_id')
  stmt.query_single_value(order_id: 1)
  stmt.query_single_value(order_id: 2)
  ```

  Prepared statements can provide a nice performance boost (on top of
  Extralite's already [very fast
  performance](https://github.com/digital-fabric/extralite#performance)) as they
  are compiled only once and can then be reused repeatedly without recompiling
  on each invocation.

- A bundled version of Extralite now includes the latest version of SQLite
  (currently at version 3.38.0). This provides a double advantage: there's no
  need to install the sqlite3 lib on your system, and you can use the latest
  features provided by SQLite. In order to use the bundled Extralite gem, just
  add `gem 'extralite-bundle'` instead of `gem 'extralite'` to your Gemfile. The
  API stays exactly the same.

## Papercraft - composable templating for Ruby

[Papercraft](https://github.com/digital-fabric/papercraft) also got a lot of
attention in the last month:

- Added support for XML namespaced tags and attributes.
- Added bundled SOAP extension for creating SOAP request/response bodies
  (contributed by [@aemadrid](https://github.com/aemadrid)).
- Refactored, cleaned up and documented the entire code base.

Papercraft is used to generate the web page you're currently reading: the [page
content](https://github.com/ciconia/noteflakes.com/blob/main/sites/noteflakes.com/articles/2022-03-05-february-summary.md)
is in [Markdown], the [article
layout](https://github.com/ciconia/noteflakes.com/blob/main/sites/noteflakes.com/_layouts/article.rb)
is a Papercraft template, derived from the [default
layout](https://github.com/ciconia/noteflakes.com/blob/main/sites/noteflakes.com/_layouts/default.rb).
The RSS feed for this website is also
[implemented](https://github.com/ciconia/noteflakes.com/blob/main/sites/noteflakes.com/feeds/rss.rb)
as a Papercraft template.

I'm looking for contributors willing to integrate Papercraft into Rails. Let me
know if you're interested!

## Impression - a web framework (WIP)

[Impression](https://github.com/digital-fabric/impression) is a relatively
recent project I put together for building the present website ([code
here](https://github.com/ciconia/noteflakes.com)). It's still more of a rough
sketch than anything serious, but it presents a novel way (I believe) to look at
web apps.

Instead of the standard MVC pattern (and related patterns as well,) Impression
is based around a single entity - the resource. A resource lives in a tree
structure (rooted in a root resource). Different kinds of resources provide
different functionalities. For example, there's a resource for serving static
files, there's a resource for running a Rack app, there's a resource for serving
Jamstack-like websites, etc.

An Impression-based application is then simply a tree of resources. For example:

```

* /               => Impression::App
|
+-* /static       => Impression::FileTree
|
+-* /api
  |
  +-* /api/users  => Impression::RestfulAPI
  |
  +-* /api/orders => Impression::RestfulAPI
```

Each resource above is mounted at a specific location in the URL namespace.
Incoming HTTP requests are first routed to the corresponding resource, which
then handles the request and generates a response.

So the idea is to be able to build an app out of those different resource types,
and for each resource to be designed to fit the specific functionality required.
This design seems to me to be both simple and flexible.

The resource used for the present website is called `Impression::App`. It
resembles a Jamstack app in that it renders any static assets in the given file
directory, but it can also render markdown files with layouts, *and*
dynamically load resource modules written in Ruby. For example, the Noteflakes
website has a [`/ping`](/ping) endpoint, which simply responds with a `pong`.
Here's the source code for the endpoint:

```ruby
# In this case, the endpoint is a basic resource with a custom response block.
export_default Impression.resource { |req|
  req.respond('pong')
}
```

That way, an Impression application can be composed of a bunch of dynamically
loaded resources that are "mounted" according to their location in the app's
file tree. In the future, Impression apps will also be able to automatically
reload resource files that have been updated. I hope to be able to write more
about impression in due time.

## H1P - HTTP/1 parser for Ruby

[H1P](https://github.com/digital-fabric/h1p) got the ability to [parse HTTP/1
responses](https://github.com/digital-fabric/h1p/commit/62868679a164af859e8153d5c50e0f4cf567ecad)
as well as requests, so now you can also use it to implement HTTP clients.
Here's a basic example:

```ruby
require 'socket'
require 'h1p'

conn = TCPSocket.new('ipinfo.io', 80)
parser = H1P::Parser.new(conn, :client)

# send request
conn << "GET / HTTP/1.1\r\nHost: ipinfo.io\r\n\r\n"

# read response
headers = parser.parse_headers
body = parser.read_body

conn.close
p headers
p body
```

Notice how the code above doesn't need to deal with reading or buffering
incoming data. It's automatically handled by the H1P parser, and what you get in
the end is a hash with the response headers, and of course the response body.
It's that simple! For more information, go to the [H1P project
page](https://github.com/digital-fabric/h1p).

## Perspectives for this month

In the month of March, I'll be concentrating on the following areas:

- Polyphony: I've written in the past about being able to [express I/O
  operations in terms of a composition of
  steps.](./2021-10-05-a-compositional-approach-to-ruby-performance) Lately I've
  been thinking about how that relates to being able to do data compression on
  the fly. One use case for that would be sending and receving gzip'ed or
  deflated HTTP responses.

  As I always start with designing the API, I came up with this:

  ```ruby
  module ResponseExtensions
    def serve_io_gzipped(io)
      r, w = IO.pipe
      spin do
        io.gzip(w)
        w.close
      end
      serve_io(r)
    end
  end
  ```

  The idea here is to maximize performance and minimize allocations and GC
  pressure by doing as much of the work using pipes, which are basically [kernel
  buffers](https://yarchive.net/comp/linux/splice.html). We do need to spin up a
  fiber but that's the only cost, and thanks to Polyphony's innovative design,
  we get both optimized I/O scheduling and automatic back-pressure.

  I'll dedicate a future article to how this mechanism once it is implemented.

- H2P: This is a new gem for implementing HTTP/2 servers and clients. The idea
  is to provide the same kind blocking API design that underlies
  [H1P](https://github.com/digital-fabric/h1p) (discussed above). Here's an
  example of how an HTTP/2 server implementation might look like:

  ```ruby
  def handle_incoming_http2_connection(conn, &handler)
    h2p = H2P::Peer.new(conn, :server)
    h2p.each do |stream_id, headers|
      # each stream gets its own fiber
      handle_http2_stream(h2p, stream_id, headers, &handler)
    end
  end

  def handle_http2_stream(h2p, stream_id, headers, &handler)
    spin do
      stream_adapter = H2StreamAdapter.new(h2p, stream_id)
      req = Qeweney::Request.new(headers, stream_adapter)
      handler.(req)
    end
  end

  class H2StreamAdapter
    ...

    def respond(request, body, headers)
      @h2p.send_headers(@stream_id, headers, done: false)
      @h2p.send_data(@stream_id, body, done: true)
    end
  end
  ```

- Inuit - this is another new gem that I'm currently designing, meant to be a
  Polyphony-based HTTP client with the following features:

  - Support for HTTP/1, HTTP/2, WebSocket.
  - Support for HTTPS, WSS.
  - Persistent connections, connection pooling.
  - Support for sessions and cookies.

Please [let me know](/about#contact) if my work interests you. You can delve
into my code [here](https://github.com/ciconia).