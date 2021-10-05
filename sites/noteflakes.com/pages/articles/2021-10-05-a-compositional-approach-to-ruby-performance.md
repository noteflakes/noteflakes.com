---
title: "A Compositional Approach to Optimizing the Performance of Ruby Apps"
date: 2021-10-05
layout: article
---

Ruby has long been derided as a slow programming language. While this accusation
has some element of truth to it, successive Ruby versions, released yearly, have
made great strides in improving Ruby's performance characteristics.

In addition to all the iterative performance improvements - Ruby 2.6 and 2.7
were especially impressive in terms of performance gains - recent versions have
introduced bigger features aimed at improving performance, namely: a [JIT
compiler](https://k0kubun.medium.com/the-method-jit-compiler-for-ruby-2-6-388ee0989c13),
the [Ractor](https://rubyapi.org/3.0/o/ractor) API for achieving parallelism,
and the [Fiber scheduler](https://rubyapi.org/3.0/o/fiber/schedulerinterface)
interface aimed at improving concurrency for I/O bound applications.

While those three big developments have yet to prove themselves in real-life
Ruby apps, they represent great opportunities for improving the performance of
Ruby-based apps. The next few years will tell if any of those new technologies
will deliver on its promise for Ruby developers.

While Ruby developers (especially those working in and around Ruby on Rails) are
still looking for the holy grail of Ruby fastness, I'd like to explore a
different way of thinking about developing Ruby apps (and gems) that can be
employed to achieve optimal performance.

## Ruby Makes Developers Happy, Until it Comes to Performance...

Why do I love programming in Ruby? First of all, because it's optimized for
developer happiness. Ruby is famous for allowing you to express your ideas in
any number of ways. You can write functional programs, or go all in on Java-like
enterprise OOP patterns. You can build DSLs, and you can replace or extend whole
chunks of the Ruby core functionality by redefining core class methods. And
metaprogramming in Ruby lets you do nuclear stuff!

All this comes, of course, with a price tag in the form of reduced performance
when compared to other, less magical, programming languages, such as Go, C or
C++. But experienced Ruby developers will have already learned how to get the
most "bang for the buck" out of Ruby, by carefully designing their code so as to
minimize object allocations (and subsequent GC cycles), and picking core Ruby
and Stdlib APIs that provide better performance.

Another significant way Ruby developers have been dealing with problematic
performance is by using Ruby C-extensions, which implement specific
functionalities in native compiled code that can be invoked from plain Ruby
code.

## Compositional Programming in Ruby

It has occurred to me during my work on
[Polyphony](https://github.com/digital-fabric/polyphony), a concurrency library
for Ruby, that a C-extension API can be designed in such a way as to provide a
small, task-specific execution layer for small programs composed of multiple
steps that can be exspressed as data structures using plain Ruby objects. Let me
explain using an example.

Let's say we are implementing an HTTP server, and we would like to implement
sending a large response using [chunked
encoding](https://en.wikipedia.org/wiki/Chunked_transfer_encoding). Here's how
we can do this in Ruby:

```ruby
def send_chunked_encoding(data, chunk_size)
  idx = 0
  len = data.bytesize
  while idx < len
    chunk = data[idx...(idx += chunk_size)]
    @socket << "#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n"
  end
  # send empty chunk
  @socket << "0\r\n\r\n"
end
```

This is pretty short and sweet, but look how we're allocating a string for each
chunk and doing index arythmetic in Ruby. This kind of code surely could be made
more efficient by reimplementing it as a C-extension. But if we already go to
the trouble of writing a C-extension, we might want to generalize this approach,
so we might be able to implement sending chunked data over other protocols as
well.

What if we could come up with a method implemented in C, that takes a
*description* of what we're trying to do? Suppose we have a method with the
following interface:

```ruby
def send_data_in_chunks(
    data,
    chunk_size,
    chunk_head,
    chunk_tail
  )
end
```

We could then implement HTTP/1 chunked encoding by doing the following:

```ruby
def send_chunked_encoding(data, chunk_size)
  @socket.send_data_in_chunks(
    data,
    chunk_size,
    ->(len) { "#{len.to_s(16)}\r\n" }, # chunk size + CRLF
    "\r\n"                             # trailing CRLF
  )
end
```

If the `#send_data_in_chunks` method is implemented in C, this means that Ruby
code is not involved at all in the actual sending of the data. The C-extension
code is responsible for looping and writing the data to the socket, and the Ruby
code just provides instructions for what to send before and after each chunk.

## Polyphony's chunked splicing API

The above approach is actually how static file responses are generated in
[Tipi](https://github.com/digital-fabric/tipi), the web server for Ruby I'm
currently developing. One of Tipi's distinguishing features is that it can send
large files without ever loading them into memory, by using Polyphony's
`Backend#splice_chunks` API (Polyphony emulates splicing on non-Linux OSes).
Here's an excerpt from Tipi's HTTP/1 adapter code:

```ruby
def respond_from_io(request, io, headers, chunk_size = 2**14)
  formatted_headers = format_headers(headers, true, true)
  request.tx_incr(formatted_headers.bytesize)

  Thread.current.backend.splice_chunks(
    io,
    @conn,
    formatted_headers,
    "0\r\n\r\n",
    ->(len) { "#{len.to_s(16)}\r\n" },
    "\r\n",
    chunk_size
  )
end
```

The `Backend#splice_chunks` method is slightly more sophisticated than the
previous example, as it also takes a string to send *before all chunks* (here
it's the HTTP headers), and a string to send *after all chunks* (the empty chunk
string `"0\r\n\r\n"`). My [non-scientific
benchmarks](/articles/2021-06-25-polyphony-june-edition#a-new-api-for-splicing-tofrom-pipes)
have shown speed gains of up to 64% for multi-megabyte HTTP responses!

The main idea behind the `#splice_chunks` API is that the application provides a
*plan*, or a *program* for what to do, and the underlying system "runs" that
program.

## Chaining multiple I/O operations in a single Ruby method call

A similar approach was also used to implement chaining of multiple I/O
operations, a feature particularly useful when running on recent Linux kernels
with io_uring (Polyphony automatically uses io_uring starting from Linux version
5.6.) Here again, the same idea is employed - the application provides a
"program" expressed using plain Ruby objects. Here's how chunked transfer
encoding can be implemented using `Backend#chain` (when splicing a single chunk
from an IO instance):

```ruby
def send_chunk_from_io(io, chunk_size)
  r, w = IO.pipe
  len = w.splice(io, chunk_size)
  if len > 0
    Thread.current.backend.chain(
      [:write, @conn, "#{len.to_s(16)}\r\n"],
      [:splice, r, @conn, len],
      [:write, @conn, "\r\n"]
    )
  else
    @conn.write("0\r\n\r\n")
  end
  len
end
```

Let's take a closer look at the call to `#chain`:

```ruby
Thread.current.backend.chain(
  [:write, @conn, "#{len.to_s(16)}\r\n"],
  [:splice, r, @conn, len],
  [:write, @conn, "\r\n"]
)
```

The `Backend#chain` API takes one or more Ruby arrays each an I/O operation. The
currently supported operations are `:write`, `:send` and `:splice`. For each
operation we provide the operation type followed by its arguments. The most
interesting aspect of this API is that it allows us to reap the full benefits of
using io_uring, as the given operations are
[linked](https://unixism.net/loti/tutorial/link_liburing.html) so that they will
be performed by the kernel one after the other without the Ruby code ever being
involved! The `#chain` method will return control to the Ruby layer once all
operations have been performed by the kernel.

## Designing Compositional APIs

This approach to API design might be called compositional APIs - the idea here
is that the API provides a way to *compose* multiple tasks or operations by
describing them using native data structures.

Interestingly enough, io_uring itself takes this approach: you describe I/O
operations using [SQEs (submission queue
entries)](https://unixism.net/loti/ref-liburing/submission.html), which are
nothing more than C data structures conforming to a standard interface. In
addition, as mentioned above, with io_uring you can chain multiple operations to
be performed one after another.

Future plans for io_uring include making it possible to submit
[eBPF](https://en.wikipedia.org/wiki/Berkeley_Packet_Filter) programs for
running arbitrary eBPF code kernel side. That way, we might be able to implement
chunked encoding in eBPF code, and submit it to the kernel using io_uring.

## A More General Approach to Chaining I/O operations

It has recently occurred to me that the compositional approach to designing APIs
can be further enhanced and generalized, for example by providing the ability to
express flow control. Here's how the chunk splicing functionality might be
expressed using such an API:

```ruby
def respond_from_io(request, io, headers, chunk_size = 2**14)
  formatted_headers = format_headers(headers, true, true)
  r, w = IO.pipe

  Thread.backend.submit(
    [:write, @conn, formatted_headers],
    [:loop,
      [:splice, io, w, chunk_size],
      [:break_if_ret_eq, 0],
      [:store_ret, :len], # store the return code in @len
      [:write, @conn, ->(ret) { "#{ret.to_s(16)}\r\n" }],
      [:splice, r, @conn, :len], # use stored @len value
      [:write, @conn, "\r\n"]
    ],
    [:write, @conn, "0\r\n\r\n"]
  )
end
```

Now there are clearly a few problems here: this kind of API can quickly run into
the problem of Turing-completeness - will developers be able to express *any*
kind of program using this API? Where are the boundaries and how do we define them?

Also, how can we avoid having to allocate all those arrays every time we call
the `#respond_from_io` method? All those allocations can put more pressure on
the Ruby GC, and themselves can be costly in terms of performance. And that proc
we provide - it's still Ruby code that needs to be called for every iteration of
the loop. That too can be costly to performance.

The answers to all those questions are still not clear to me, but one solution I
thought about was to provide a "library" of operation types that is a bit
higher-level than a simple write or splice. For example, we can come up with an
operation to write the chunk header, which can look something like this:

```ruby
Thread.backend.submit(
  [:write, @conn, formatted_headers],
  [:loop,
    [:splice, io, w, chunk_size],
    [:break_if_ret_eq, 0],
    [:store_ret, :len],
    [:write_cte_chunk_size, @conn, :len],
    [:splice, r, @conn, :len],
    [:write, @conn, "\r\n"]
  ],
  [:write, @conn, "0\r\n\r\n"]
)
```

## Adding IO References

Another improvement we can make is to provide a way to reference io instances
and dynamic strings from our `respond_from_io` "program" using indexes. This
will allow us to avoid allocating all those arrays on each invocation:

```ruby
# program references:
# 0 - headers
# 1 - io
# 2 - @conn
# 3 - pipe r
# 4 - pipe w
# 5 - chunk_size
RESPOND_FROM_IO_PROGRAM = [
  [:write, 2, 0],
  [:loop,
    [:splice, 1, 4, 5],
    [:break_if_ret_eq, 0],
    [:store_ret, :len],
    [:write_cte_chunk_size, 2, :len],
    [:splice, 3, 2, :len],
    [:write, 2, "\r\n"]
  ],
  [:write, 2, "0\r\n\r\n"]
]

def respond_from_io(request, io, headers, chunk_size = 2**14)
  formatted_headers = format_headers(headers, true, true)
  r, w = IO.pipe
  Thread.backend.submit(RESPOND_FROM_IO_PROGRAM, formatted_headers, io, @conn, r, w)
end
```

## Creating IO Programs Using a DSL

Eventually, we could provide a way for developers to express IO programs with a
DSL, instead of with arrays. We could then also use symbols for representing IO indexes:

```ruby
RESPOND_FROM_IO_PROGRAM = Polyphony.io_program(
  :headers, :io, :conn, :pipe_r, :pipe_w, :chunk_size
) do
  write :conn, :headers
  io_loop do
    splice :io, :pipe_w, :chunk_size
    break_if_ret_eq 0
    store_ret :len
    write_cte_chunk_size :conn, :len
    splice :pipe_r, :conn, :len
    write :conn, "\r\n"
  end
  write :conn, "0\r\n\r\n"
end
```

Does this look better? I'm not sure. Anyways, there are some rough edges here
that will need to be smoothed out for this approach to work.

## Implementing a Protocol Parser Using the Compositional Approach

It as occurred to me that this kind of approach, expressing a "program" using
plain Ruby objects, to be executed by a C-extension, could also be applied to
protocol parsing. I've recently released a blocking HTTP/1 parser for Ruby,
called [h1p](https://github.com/digital-fabric/h1p), implemented as a Ruby C
extension, and I had some ideas about how this could be done.

We introduce a `IO#parse` method that accepts a program for parsing
characters. The program expressed includes a set of steps, each one reading
consecutive characters from the IO instance:

```ruby
# for each part of the line we can express the valid range of lengths, 
REQUEST_LINE_RULES = [
  [:read, { delimiter: ' ', length: 1..40, invalid: ["\r", "\n"], consume_delimiter: true }],
  [:consume_whitespace],
  [:read, { delimiter: ' ', length: 1..2048, invalid: ["\r", "\n"], consume_delimiter: true }],
  [:consume_whitespace],
  [:read_to_eol, { consume_eol: true, length: 6..8 } ]
]

HEADER_RULES = [
  [:read_or_eol, { delimiter: ':', length: 1..128, consume_delimiter: true }],
  [:return_if_nil],
  [:consume_whitespace],
  [:read_to_eol, { consume_eol: true, length: 1..2048, consume_delimiter: true }]
]

def parse_http1_headers
  (method, request_path, protocol) = @conn.parse(REQUEST_LINE_RULES)
  headers = {
    ':method' => method,
    ':path' => request_path,
    ':protocol' => protocol
  }
  
  while true
    (key, value) = @conn.parse(HEADER_RULES)
    return headers if !key

    headers[key.downcase] = value
  end
end
```

Here too, we can imagine being able to express these parsing rules using a DSL:

```ruby
REQUEST_LINE_RULES = Polyphony.parse_program do
  read delimiter: ' ', length: 1..40, invalid: ["\r", "\n"], consume_delimiter: true
  consume_whitespace
  read delimiter: ' ', length: 1..2048, invalid: ["\r", "\n"], consume_delimiter: true
  consume_whitespace
  read_to_eol consume_eol: true, length: 6..8
end
```

It remains to be seen where are the limits to what we can achieve with this
approach: can we really express everything that we need in order to parse *any*
conceivable protocol. In addition, it is not clear whether this kind of solution
provides performance benefits.

## Summary

In this article I have presented an approach to optimizing the performance of
Ruby apps by separating the program into two layers: a top layer that written in
Ruby, expressing low-level operations using Ruby data structures; and an
implementation layer written in C for executing those operations in an optimized
manner.

As I have mentioned above, this approach is similar to that employed by io_uring
on Linux. The idea is the same: we express (I/O) operations using data
structures, then offload the execution to an lower-level optimized layer - in
io_uring's case it's the kernel, in Ruby's case it's a C-extension.

This is definitely an avenue I intend on further exploring, and I invite other
Ruby developers to join me in this exploration. While we wait for all those
exciting Ruby developments I mentioned at the beginning of this article to
materialize (the new [YJIT](https://github.com/Shopify/yjit) effort from Shopify
looks especially promising), we can investigate other approaches that take
advantage of Ruby's expressivity while relying on native C code to execute lower
level code.
