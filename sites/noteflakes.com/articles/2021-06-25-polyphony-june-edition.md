---
title: What's new in Polyphony - June 2021 edition
layout: article
---
Polyphony 0.58 has just been released. Here's a summary and discussion of the latest changes and improvements:

- Improved functionality for OpenSSL sockets and servers.
- Fixes to the `Mutex` class.
- A redesigned event anti-starvation algorithm.
- A new API for splicing to/from pipes.
- A new API for chaining multiple I/O operations.
- New APIs for performing GC and other arbitrary work when the process is idle.

## Improved functionality for OpenSSL sockets and servers

Following the work I've lately been doing on the Tipi server (you can read more about that towards the end of this post), I've made significant improvements to working with OpenSSL encrypted servers and client sockets. Here are some of the changes:

- Add `SSLSocket#recv_loop` method (#54).
- Add `SSLServer#accept_loop` method.
- Override `SSLSocket#peeraddr` to support the same arity as `Socket#peeraddr` (#55) (this is an inconsistency at the level of the Ruby stdlib.)

## Fixes to the `Mutex` class

Following a [bug report](https://github.com/digital-fabric/polyphony/issues/50) from @primeapple, trying to use Polyphony in a Rails project (!), some missing methods were added to the Polyphony implementation of the Mutex class: `#owned?` and `#locked?`.

It is still too early to tell if Polyphony can be used to drive a Rails app, and frankly I am not actively trying to make it happen, but I'd love to receive more feedback on how Polyphony interacts with different parts of the Rails ecosystem.

## A redesigned event anti-starvation algorithm

Polyphony is at its core an efficient fiber scheduler that eschews the traditional non-blocking design that wraps the entire program in one big event loop. Instead, when a fiber needs to perform some long-running operation, it simply passes control to the next fiber on the run queue. If the run queue is empty, the backend is polled for completion of events or operations. This is a blocking call that will return only when one or more events are available for the backend to process. Each completed event or operation will cause the corresponding fiber to be scheduled, and to be eventually resumed.

Under certain circumstances, though, if the runqueue is never empty (because fibers are kept being scheduled regardless of I/O events), this will prevent Polyphony from polling for events, leading to *event starvation*.

In order to prevent this from happening, Polyphony includes a mechanism for periodically performing a *non-blocking* poll, which assures the processing of ready events, even under such conditions. For the libev backend, this is done by calling `ev_run(backend->ev_loop, EVRUN_NOWAIT)`, which will only process ready events without waiting. For the io_uring backend this done by simply processing the available CQEs without issuing a `io_uring_enter` system call.

Now, until Polyphony version 0.54, determining *when* to use this mechanism was problematic, and was based on false assumptions. In Polyphony 0.55 the algorithm for determining when to make a non-blocking poll was redesigned, and is now based on counting the number of times fibers have been switched, as well as keeping a high water mark for the number of fibers in the run queue:

- A switch counter is incremented every time a fiber is pulled off the run queue.
- The switch counter is reset when the run queue is empty.
- A high water mark is updated every time it's exceeded by the run queue size (when adding fibers to the run queue).
- The non-blocking poll is performed when both the high water mark and the switch count reach certain thresholds (currently set at 128 and 64 respectively).

If this tickles your interest, you can have a look at [the code](https://github.com/digital-fabric/polyphony/blob/master/ext/polyphony/runqueue.c).

## A new API for splicing to/from pipes

The Linux kernel includes a relatively little known system call called `splice`, which lets developers move data from one file descriptor to another (for example, from a file to a socket) without needing to copy data back and forth between userspace and the kernel, a costly operation, and in some cases even without copying data inside the kernel itself, by using pipes (which act as kernel buffers). To learn more about `splice` and what it's good for, read [this explanation](https://yarchive.net/comp/linux/splice.html) by Linus Torvalds himself.

Starting from Polyphony 0.53, I've been gradually adding support for splicing to and from I/Os on both the libev and io_uring backends. The following APIs were added:

- `Backend#splice(src, dest, maxlen)`
- `Backend#splice_to_eof(src, dest, chunk_size)`

In addition, the corresponding methods have been added to the `IO` class:

- `IO#splice(src, maxlen)` - returns the number of bytes written
- `IO#splice_to_eof(src, chunk_size = 8192)` - returns the number bytes written

So we know that to `splice` we need to use a pipe, either for the source or the destination or for both, but how do we use it in practice? Suppose we want to write the content of a file to a socket. Here's one way we can do this with `splice`:

```ruby
def write_file_to_socket(socket, path)
  r, w = IO.pipe
  File.open(path, 'r') do |f|
    spin do
      w.splice_to_eof(f)
    ensure
      w.close
    end
    socket.splice_to_eof(r)
  end
end
```

In the above example we create a pipe, and then we spin up a separate fiber that will splice from the file to the pipe, while the current fiber splices from the pipe to the socket. This technique can be used for files of arbitrary size (even GBs), without loading the file content into Ruby strings and putting pressure on the Ruby garbage collector. On top of this, we do this concurrently and with automatic backpressure (i.e. our socket will not get inondated with MBs of data.)

While the `splice` system call is only available on Linux, the libev backend includes fake implementations of `Backend#splice` and `Backend#splice_to_eof` done with plain `read` and `write` calls.  

In addition to the above new methods, Polyphony 0.57 also introduces the `Backend#splice_chunks` method, which can be used for splicing chunks to some arbitrary destination IO instance, interespersed with writing plain Ruby strings to it. The use case arose while working on the [Tipi web server](https://github.com/digital-fabric/tipi), and trying to optimize serving static files on the web without loading the file content in Ruby strings. The Tipi HTTP/1.1 adapter tries whenver possible to use chunked encoding. In HTTP/1.1 for each chunk there should be a header including the chunk size, followed by the chunk itself, and finally a `\r\n` delimiter. In order to abstract away the creation of a pipe (for use with splicing) and the looping etc, I introduced the following method:

```
Backend#splice_chunks(src, dest, prefix, postfix, chunk_prefix, chunk_postfix, chunk_size)
```

... with the following arguments:

- `src` - source IO instance
- `dest` - destination IO instance
- `prefix` - prefix to write to destination before splicing from the source
- `postfix` - postfix to write to destination after splicing is done
- `chunk_prefix` - the prefix to write before each chunk (a string or a proc)
- `chunk_postfix` - the postfix to write after each chunk (a string or a proc)
- `chunk_size` - the maximum chunk size

The chunk prefix and postfix can be a `Proc` that accepts the length of the current chunk, and returns a string to be written to the destination. Here's how this new API is used in Tipi to serve big files:

```ruby
# Edited for brevity
def respond_from_io(request, io, headers, chunk_size = 2**14)
  formatted_headers = format_headers(headers)
  Thread.current.backend.splice_chunks(
    io,
    @conn,
    # prefix: HTTP headers
    formatted_headers,
    # postfix: empty chunk denotes end of response 
    "0\r\n\r\n", 
    # dynamic chunk prefix with the chunk length
    ->(len) { "#{len.to_s(16)}\r\n" },
    # chunk delimiter 
    "\r\n", 
    chunk_size
  )
end
```

As the example demonstrates, this allows sending chunks from arbitrary IO instances (be it files or sockets or STDIO or pipes) without any of the data passing through the Ruby runtime, and the API is concise but also allows lots of flexibility. We can imagine using this API to send HTTP/2 data frames without much difficulty.

While the libev backend is more or less straightforward - doing splicing and writing sequentially one after the other, the io_uring backend implementation benefits from being able to issue multiple *ordered* I/O operations at once using the `IOSQE_IO_LINK` flag. This allows us to further minimize the number of system calls we make.

But what of the performance implications? Does using this technique result in any noticable improvements to performance? It's still too early to tell how using this technique will affect the numbers in a real-world situation, but preliminary benchmarks for [serving static files with Tipi](https://github.com/digital-fabric/tipi/blob/master/examples/http_server_static.rb) show a marked improvement for files bigger than 1MB:

|File size|Normal - req/s|Spliced - req/s|Change|
|--------:|-------------:|--------------:|-----:|
|  1KB    |          8300|           7568|   -8%|
| 64KB    |          7256|           5702|  -21%|
|  1MB    |           730|            768|   +5%|
|  4MB    |           130|            189|  +45%|
| 16MB    |            28|             46|  +64%|
|  64M    |             9|             12|  +33%|
|256MB    |             2|              3|  +50%|

> This benchmark was done using the io_uring backend, using `wrk` with the stock settings, i.e. 2 threads and 10 concurrent connections, on an lowly EC2 t3.xlarge machine.

## A new API for chaining multiple I/O operations

Another big new feature introduced in Polyphony 0.55 is chaining of multiple ordered I/O operations using the `Backend#chain` API, which allows developers to specify multiple (outgoing) I/O operations in a single call to the backend, in order to minimize the overhead involved in going back and forth between the fiber issuing the I/O operations and the backend.

While Polyphony can already write multiple strings to the same file descriptor with a single method call (using `writev`), this new API allows developers to perform multiple I/O operations on different file descriptors in a single method call.

Here as well, the io_uring backend can reap additional performance benefits by issuing multiple ordered I/O operations using a single system call, without having to wakeup the fiber after each I/O operation, in a similar fashion to the `Backend#splice_chunks` API we just discussed.

The `Backend#chain` method takes one or more operation specifications expressed using plain arrays. Here's a simplified version of `Backend#splice_chunks` implemented using the `#chain` API:

```ruby
def splice_chunks_in_ruby(src, dest, prefix, postfix, chunk_size)
  r, w = IO.pipe
  while true
    len = w.splice(src, chunk_size)
    break if len == 0

    chain(
      [:write, dest, prefix],
      [:splice, r, dest, len],
      [:write, dest, postfix]
    )
  end
end
```

The following operation specifications are currently supported:

- `[:write, destination, data]`
- `[:send, destination, data, flags]` - for sockets only
- `[:splice, source, destination, len]`

## New APIs for performing GC and other arbitrary work when idle

When running web servers in production, I'd like not only to maximize the server's throughput (expressed in requests per second), but also minimize latency. And when we talk about latency we also need to talk about percentiles. One of the things that can really hurt those 99th percentile latency numbers in Ruby web servers is the fact that the Ruby runtime needs to perform garbage collection from time to time, and normally this garbage collection event is both slow (costing tens of milliseconds or even more), and can come at any time, including while processing an incoming request.

In order to prevent garbage collection from happening while your server is busy preparing a response, a technique called out-of-band GC, or out-of-band processing, consists of disabling the garbage collector, and manually running a GC cycle when the server is otherwise idle (i.e. not busy serving requests.) 

Polyphony 0.58 introduces new APIs that allow you to perform garbage collection or run any code only when the process is otherwise idle (i.e. when no fibers are scheduled.) Here are the new APIs:

- `Thread#idle_gc_period=` - sets the period (in seconds) for performing GC when idle.
- `Thread#on_idle { ... }` - installs a block to be executed whenever the system is idle.

Here's how you can set automatic GC when idle:

```ruby
# Here we set the minimum interval between consecutive GC's done only when the
# thread is otherwise idle to 60 seconds:
Thread.current.idle_gc_period = 60

GC.disable
```

You can also run an arbitrary block of code when idle by passing a block to `Thread#on_idle`:

```ruby
Thread.current.on_idle do
  do_something_really_unimportant
end
```

## What's next for Polyphony?

Polyphony has been in development for almost three years now, and its API is slowly stabilizing. I'd like to be able to release version 1.0 in a few month but I still have some work left before we arrive there, including:

- Support for UDP sockets.
- Support for IPv6.
- Redesign the fiber supervision API.

As for actual applications using Polyphony, I am continuing work on the Tipi web server, which is already used in production (in a closed-source product for one of my clients), and which already knows how to do HTTP/1.1, HTTP/2, Websockets and SSL termination.

I am currently working on two really exciting things:

- Add automatic SSL certificate provisioning to Tipi, using the ACME protocol with providers such as Let's Encrypt. This will allow developers to run Tipi as an all-in-one app- *and* web server, without needing to use a reverse proxy such as Nginx or Caddy at all!
- Implement a modern HTTP client for Ruby based on Polyphony, with features such as persistent connections by default, automatic support for HTTP/2 connections, sessions, caching and persistent cookies to name but a few.
